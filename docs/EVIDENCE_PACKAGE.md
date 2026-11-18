# Evidence Package — Usage Guide

`scripts/run_evidence_package.sh` is the single entry point that produces, hashes and
verifies the evidence behind this repository's verification claims. It replaces the
previous workflow of hand-running the scale matrix, the zk benchmark and the formal
bundle builder separately and hoping all three artifacts landed in the same place.

This document covers prerequisites, every option, every stage, the output layout, how
to verify a package you did not produce yourself, and what the package does **not**
establish.

---

## 1. Quick start

```bash
# Everything that fits the current host (skips the Kind stage if kind is absent)
bash scripts/run_evidence_package.sh

# Explicit: no Kubernetes scale stage
bash scripts/run_evidence_package.sh --skip-kind

# Everything, and fail rather than skip when a tool is missing
bash scripts/run_evidence_package.sh --strict
```

A run prints one `[package] --- <stage>: start/done` block per stage and finishes with
the package directory, its manifest, and its size. Any missing artifact fails the run.

Typical wall clock on a 16-core workstation: **~3–5 minutes** without the Kind stage,
**~20–40 minutes** with it.

---

## 2. Prerequisites

| Stage | Requires | Notes |
| --- | --- | --- |
| `zk-bench` | `go` | ~45 s. The one-time trusted setup dominates; the prove itself is ~30 ms. |
| `zk-round` | `go` | ~45 s (again mostly setup). Produces the end-to-end prove→verify log. |
| `scale` | `kind`, `kubectl`, `docker` | Opt-in in practice. `--skip-kind` or a missing `kind` binary skips it unless `--strict`. |
| `dp` | `go` | ~10 s. Runs the RDP accountant tests and records the output. |
| `formal` | `python3` | ~30 s. Regenerates the Lean validation report and the tamper-evident bundle. |
| `manifest` | `python3` | Instant. Hashes every artifact. |

`go` must be on `PATH` and able to build the repo (on this host:
`source scripts/ensure_go_toolchain.sh` first if your toolchain is elan-managed).

Nothing else is needed. There is no cluster, cloud account or secret involved.

---

## 3. Options

| Option | Meaning | Default |
| --- | --- | --- |
| `--out DIR` | Parent directory for run subdirectories | `results/evidence-package` |
| `--stages LIST` | Comma-separated subset, in canonical order | `zk-bench,zk-round,scale,dp,formal,manifest` |
| `--skip-kind` | Do not run (and do not require) the Kind scale stage | off |
| `--strict` | A stage that would be skipped because a tool is missing is a failure instead | off |
| `-h`, `--help` | Print the header comment and exit | — |

Environment overrides honoured by the underlying scripts: `NAMESPACE`,
`REPLICAS_LIST`, `CLUSTER_NAME`, `WINDOW_SECONDS`, `OUT_DIR` (for the scale stage).

Runs are written to `RUN_DIR/run-<UTC timestamp>/`, so repeated runs never overwrite
each other.

---

## 4. Stages

### `zk-bench` — measured prover / verifier

Runs `go run ./cmd/zkweightbench`, which compiles `WeightUpdateCircuit`, runs the
simulated multi-party trusted setup, then measures prove and verify over 20 / 200
iterations and enforces budgets.

Artifacts: `zk/weight-proof-latest.json` (constraints, setup/prove/verify timings,
budgets, violations), `zk-bench.log`.

**Read it as:** the current, honest cost of the ZK path. `setup` is the one-time
compile + simulated ceremony (~41 s); `prove` is the per-update cost (~30 ms);
`verify` is what the aggregator pays (~0.7 ms). Do **not** read `setup` as prove
time — an earlier revision of `cmd/simulate` did exactly that and it took a review
to untangle.

### `zk-round` — end-to-end round

Runs `go run ./cmd/simulate`: builds a real witness, proves it, and lets
`internal/batch.Aggregator.ProcessRound` verify it before accepting the round.

Artifact: `zk-round.log`.

**Read it as:** the binding claim is operational — a proof is produced *and* checked
against the caller's statement in a 10 %-Byzantine round. If the statement were not
bound, `ProcessRound` would reject.

### `scale` — hierarchical scale matrix

Runs `scripts/run_kind_scale_evidence.sh` (`run_kind_scale_matrix.sh` +
`collect_kind_scale_latency.sh`) into `scale/`.

Artifacts: whatever the scale scripts write under `scale/`, plus `scale.log`.

**Read it as:** the only stage that needs infrastructure. It is the weakest link in
the package because it depends on a local Docker/Kubernetes setup; use `--strict` in
CI if you want its absence to be a hard failure.

### `dp` — differential-privacy accounting

Runs the RDP accountant tests and captures the output, prefixed with the exact
command and timestamp.

Artifact: `dp-accounting.log`.

### `formal` — Lean validation report + bundle

Runs, in order:

```
python3 scripts/ci/generate_formal_validation_report.py --repo-root .
python3 scripts/ci/build_formal_verification_bundle.py
python3 scripts/ci/verify_formal_verification_bundle.py
```

Artifacts: `formal/formal_validation_report.json`,
`formal/formal-verification-bundle/bundle_manifest.json`, and the three `.log` files.

**Read it as:** the machine-checkable statement of what Lean does and does not prove,
plus a bundle whose SHA256 manifest and Merkle root let a third party confirm nothing
was edited after the fact.

> **Side effect / host dependence.** The two generators write to the repository's
> canonical `results/proofs/` location (that is what CI does too), and the stage then
> copies their output into the package. `generate_formal_validation_report.py`
> hashes working-tree files, so its output depends on the host's line endings. A
> package produced on Windows therefore differs byte-wise from one produced on Linux
> even when the mathematics is identical — compare the *numbers*, not the hashes of
> `go.mod`. The committed `results/proofs/*` artifacts are the Linux-generated ones;
> do not overwrite them from a Windows run (`full-validation-fast` runs
> `--check` and would fail).

### `manifest` — hash everything

Walks the package directory, SHA256-hashes every file (except `manifest.json` itself),
and writes `manifest.json` with a Merkle-style root over the sorted
`sha256  path` lines.

**Read it as:** the integrity layer for the whole package. Verify it with the one-liner
in §6.

---

## 5. Output layout

```
results/evidence-package/
└── run-20261118T180000Z/
    ├── manifest.json                        # hashes + merkle root for everything below
    ├── zk-bench.log
    ├── zk-round.log
    ├── dp-accounting.log
    ├── zk/
    │   └── weight-proof-latest.json
    ├── scale/                               # present only when the stage ran
    │   └── …
    └── formal/
        ├── generate.log
        ├── bundle.log
        ├── verify.log
        ├── formal_validation_report.json
        └── formal-verification-bundle/
            ├── bundle_manifest.json
            └── …
```

Every stage appends its artifacts to a shared list; the gate at the end fails the run
if any of them is missing or empty. A run is therefore all-or-nothing by construction.

---

## 6. Verifying a package you did not produce

```bash
python3 - <<'PY'
import hashlib, json, sys
from pathlib import Path
pkg = Path("results/evidence-package/run-<timestamp>")
m = json.loads((pkg / "manifest.json").read_text())
bad = []
for e in m["files"]:
    p = pkg / e["path"]
    got = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
    if got != e["sha256"]:
        bad.append(e["path"])
root = hashlib.sha256("\n".join(f"{e['sha256']}  {e['path']}" for e in m["files"]).encode()).hexdigest()
print("files:", len(m["files"]), "mismatched:", bad, "root ok:", root == m["merkle_root"])
PY
```

Then verify the formal bundle independently:

```bash
python3 scripts/ci/verify_formal_verification_bundle.py \
  --bundle-dir results/evidence-package/run-<timestamp>/formal/formal-verification-bundle
```

---

## 7. Using it in CI

Add a job that runs the script and uploads the run directory as an artifact:

```yaml
      - name: Build evidence package
        run: bash scripts/run_evidence_package.sh --strict

      - name: Upload evidence package
        uses: actions/upload-artifact@<pinned-sha>
        if: always()
        with:
          name: evidence-package
          path: results/evidence-package/
```

Use `--strict` so a silently missing tool cannot produce a package that looks complete.
Commit the run directory if you want the numbers to be citable from the repository
rather than from a CI artifact.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `error: required command not found: go` | Go not on `PATH` | `source scripts/ensure_go_toolchain.sh` |
| `scale: 'kind' not found on PATH` | No Kind cluster tooling | pass `--skip-kind`, or install `kind` |
| `scale` fails inside `run_kind_scale_matrix.sh` | Docker daemon down, or `deploy/kubernetes/scale-test/kind-config.yaml` missing | start Docker Desktop; confirm the config path |
| `formal` fails with `missing report file` | `generate_formal_validation_report.py` did not run or failed | read `formal/generate.log`; the script is `set -e`, so the real error is earlier in the log |
| `[package] MISSING: …` at the end | A stage exited 0 without writing its artifact | run that stage by hand and check its own logging |
| zk stage takes ~45 s and you expected ms | That is the one-time setup, not the prove | read `zk/weight-proof-latest.json`: `prove.mean_ms` is the prove |

---

## 9. What this package does and does not establish

**Does:** gives a reviewer one directory containing the measured ZK cost, a real
prove-and-verify round, the DP accounting output, the hierarchical scale numbers (when
Kind is available), the Lean validation report, and a bundle whose hashes bind all of
it together.

**Does not:**

- It is **not** a production scale test. The Kind matrix runs hundreds to thousands of
  *simulated* nodes on one machine, not the 10M-node deployment target.
- It does **not** make the Go↔Lean correspondence machine-checked. Lean cannot invoke
  Go; that link stays empirical (see `proofs/FORMAL_TRACEABILITY_MATRIX.md`).
- It does **not** turn the simulated in-process MPC into a real ceremony. The trusted
  setup is a development key (see `docs/MAJOR_WIN_PLAN.md` Appendix B).
- It does **not** cover the advertised 10 ms figure, which is still a `time.sleep` in
  `sdk/python/tests/test_benchmarks.py` — retraction is deferred.
