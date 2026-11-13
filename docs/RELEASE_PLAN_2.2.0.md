# Release Plan — v2.2.0

**Status:** Draft (2026-11-13) — proposed, not scheduled.
**Owner:** TBD (release engineer + formal-methods lead)
**Companion:** `CHANGELOG.md`, `VERSION`, `docs/EXTERNAL_AUDIT_SCOPE.md`, `.github/workflows/release-assets.yml`

---

## 0. Current state

- `VERSION` = **2.1.0**; `sdk/python/mohawk/__init__.py` = 2.1.0; `check_version_sync.py` passes.
- `CHANGELOG.md` has a large `[Unreleased]` section covering 2026-10-25 → 2026-11-09.
- Lean development: **axiom-free, sorry-free** (16 → 0 axioms, 1 → 0 sorry).
- Formal bundle regenerated (PR #327): 40 files, `verify_formal_verification_bundle.py` passes.
- Last release: `v2.1.0` (2026-10-29). **All four release workflows failed on the `v2.1.0` / `v2.1.0-rc1` tags** (see §3).

---

## 1. Version bump (2.1.0 → 2.2.0)

Minor bump — new features (real ed25519/WASM, Groth16 via gnark, Noir circuit, gRPC, TEE/MPC abstractions, axiom-free Lean).

| File | Change |
|---|---|
| `VERSION` | `2.1.0` → `2.2.0` |
| `README.md` | `### Platform Upgrade (v2.1.0)` → `(v2.2.0)`; refresh the feature/verification summary |
| `CHANGELOG.md` | add `## [2.2.0] - <date>`; move the `[Unreleased]` content under it |
| `sdk/python/mohawk/__init__.py` | `__version__ = "2.2.0"` |
| `docs/EXTERNAL_AUDIT_SCOPE.md` | update "Last updated" and the audit-ready commit |

**Gate:** `python3 scripts/check_version_sync.py` must print `Version sync OK: 2.2.0`.

---

## 2. Pre-release verification (all must pass)

```bash
make audit-ready-check          # Lean build + refinement + theorem/runtime consistency
make validate-formal            # generate_formal_validation_report.py --check
python3 scripts/check_version_sync.py
make verify                     # go test ./... + audit_proofs.sh
python3 scripts/ci/check_no_unsafe_placeholders.py
python3 scripts/ci/verify_formal_verification_bundle.py
```

Plus a full CI run on the release PR with all required checks green.

---

## 3. Release workflow blockers (must be fixed first)

All four tag-triggered workflows failed on `v2.1.0` / `v2.1.0-rc1`. Fix before tagging.

### 3.1 `release-assets.yml`
- **`v2.1.0` failure:** `error: base ref 'origin/main' not found` in the "Fetch base ref" step (`git fetch origin main --depth=1`). On a tag push the remote-tracking ref is not created. **Fix:** use an explicit refspec — `git fetch origin +refs/heads/main:refs/remotes/origin/main --depth=1`.
- **`v2.1.0-rc1` failure:** `Validate Release Bundle Dry Run` → `digest-mismatch: error`. Investigate the benchmark-compare digest step (`scripts/benchmark_fedavg_compare.sh` with `BASE_REF=origin/main`).
- **Formal artifacts never staged:** the validation requires `release-assets/formal/{formal_validation_report.json, formal-verification-bundle.tar.gz, bundle_manifest.json, sha256sums.txt}`, but the "Build formal verification release artifacts" step only runs `make package-formal-verification-artifacts` (which writes to `results/proofs/`). **Fix:** add a step to copy those three files into `release-assets/formal/` and generate `sha256sums.txt` (`sha256sum release-assets/formal/* > release-assets/formal/sha256sums.txt`).

### 3.2 `slsa-provenance-and-signing.yml`
- **`build-release-binaries` failure:** `go: no Go source files` — `internal/pyapi/api.go` is cgo-gated (`import "C"`); the `python -m build` environment has cgo disabled, so the file is excluded. **Fix:** set `CGO_ENABLED: 1` at the workflow/job level and ensure a C compiler is installed (`sudo apt-get install -y build-essential`).
- **`sign-container-image` failure:** cosign signing failed; re-check after the image build is green.

### 3.3 `in-toto-supply-chain.yml`
- **`verification-step` failure:** re-run and capture the specific in-toto verification error; fix the layout/policy or the link metadata.

### 3.4 `ga-tag-safety.yml` (final tag only)
- Fails on a final `vX.Y.Z` tag because `results/go-live/evidence/go_live_gate_strict_2026-03-28.json` has `ok: false` (`host_network_tuning_ok: false`).
- **Option A:** on a host with the required sysctl tuning (`net.core.rmem_max`/`wmem_max` ≥ 8 MB, `rmem_default`/`wmem_default` ≥ 256 KB — see `scripts/validate_host_network_tuning.sh`), run `make go-live-gate-strict` and commit the passing artifact as `results/go-live/evidence/go_live_gate_strict_<date>.json`.
- **Option B:** release as a pre-release (`v2.2.0-rc1`) first; the GA safety check only applies to final `vX.Y.Z` tags.

---

## 4. Package builds (triggered by the `v*` tag)

`.github/workflows/release-assets.yml` builds and publishes:

| Asset | Source |
|---|---|
| Benchmarks | `fedavg_benchmark_compare.md`, `accelerator_backend_compare.{md,json}`, `release_performance_evidence.md`, `simulator-scale-smoke.json` |
| Guides | `BENCHMARKS_AND_REPRODUCIBILITY.md`, `ADOPTION_ACCELERATION_PLAN.md`, cloud templates |
| Source SBOM | `sbom-source.spdx.json` |
| npm packages | packed from `package.json` files (e.g. `web/ops-assistant`) |
| Testnet tarball | `sovereign-map-testnet.tar.gz` |
| Formal verification | `formal_validation_report.json`, `formal-verification-bundle.tar.gz`, `bundle_manifest.json`, `sha256sums.txt` |
| Docker images (4) | orchestrator, node-agent, fl-aggregator, api-dashboard — GHCR + OCI archives + SBOMs + digests |

Signing/attestation:
- `.github/workflows/slsa-provenance-and-signing.yml` — SLSA v1.0 provenance + cosign keyless signing.
- `.github/workflows/in-toto-supply-chain.yml` — in-toto material/build/verification attestations.
- `.github/workflows/ga-tag-safety.yml` — GA tag safety gate.

Separate Python SDK release (`.github/workflows/publish-python-sdk.yml`):
- Tag `sdk-v2.2.0` (the tag must match `sdk/python/mohawk/__init__.py`).
- Builds sdist + wheel, `twine check`, `sha256sums.txt`, optional PyPI publish.
- **Also needs the `CGO_ENABLED=1` fix** (the wheel build compiles the Go shared library).

---

## 5. Release sequence

1. **Version-bump PR** (§1) + changelog; merge to `main`.
2. **Pre-release verification** (§2); fix any failures.
3. **Fix the release workflows** (§3); verify each with a dry-run dispatch where possible.
4. **Pre-release (optional):** tag `v2.2.0-rc1`; the release workflows run; verify the assets.
5. **Final tag:** `v2.2.0`. Triggers `release-assets.yml` (publish), `slsa-provenance-and-signing.yml`, `in-toto-supply-chain.yml`, `ga-tag-safety.yml`.
6. **Python SDK:** tag `sdk-v2.2.0` (or fold into the same release).
7. **Verify** the GitHub release (§6).
8. **Post-release:** update `docs/EXTERNAL_AUDIT_SCOPE.md` with the audit-ready commit; announce.

---

## 6. Post-release verification checklist

- [ ] `gh release view v2.2.0` lists all assets (benchmarks, guides, SBOM, npm, testnet, formal, docker).
- [ ] `cosign verify` passes on the images.
- [ ] `python3 scripts/ci/verify_formal_verification_bundle.py` passes against the released bundle.
- [ ] `docker pull ghcr.io/.../sovereign-mohawk-orchestrator:v2.2.0` works.
- [ ] `python3 scripts/check_version_sync.py` passes.
- [ ] SLSA provenance and in-toto attestations attached.
- [ ] `sdk-v2.2.0` wheel/sdist published (if the SDK is released).

---

## 7. Rollback

- Delete the GitHub release and tag; re-tag after fixes.
- Docker images are immutable by tag; a bad tag can be deleted from GHCR.
- The formal bundle is a static artifact; regenerate with `scripts/ci/build_formal_verification_bundle.py` if needed.
