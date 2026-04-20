# How To Independently Verify Formal Claims

This guide provides a minimal, reproducible workflow to validate Sovereign Mohawk's formal claims from Lean source + traceability mappings + machine-checkable report artifacts.

## Prerequisites

- Linux or macOS shell environment
- Python 3.10+
- Go toolchain matching `go.mod` (`go 1.25.9`)
- Lean toolchain pinned in `proofs/lean-toolchain`

Optional (for clean-room reproducibility):

- Docker Engine + `docker compose`

## One-Command Local Verification

From repository root:

```bash
make validate-formal
```

This command fails closed if any of the following are out of sync:

- traceability matrix references
- theorem symbol mappings
- runtime test references
- machine-checkable formal report consistency
- verification bundle hash / Merkle-root integrity

## Regenerate Formal Artifacts

Use this when proof files, the matrix, or test mappings change:

```bash
make refresh-formal-validation
```

Generated artifacts:

- `results/proofs/formal_theorem_index.txt`
- `results/proofs/formal_traceability_matrix_snapshot.md`
- `results/proofs/formal_placeholder_scan.txt`
- `results/proofs/formal_validation_report.json`
- `results/proofs/formal-verification-bundle/bundle_manifest.json`
- `results/proofs/formal-verification-bundle.tar.gz`

## Verify Bundle In Isolation

```bash
python3 scripts/ci/verify_formal_verification_bundle.py \
  --bundle-dir results/proofs/formal-verification-bundle
```

The verifier checks:

- required files are present
- per-file SHA256 matches `bundle_manifest.json`
- bundle Merkle root matches manifest
- report `input_merkle_root` matches manifest
- report input hashes match manifest entries

## Reproducible Container Verification

Use the pinned formal verifier container for clean-room validation:

```bash
make validate-formal-container
```

Container image source:

- `docker/formal-verifier/Dockerfile`

Pinned baseline:

- Base image: `ubuntu:24.04`
- Lean toolchain installed via Elan: `leanprover/lean4:v4.30.0-rc2`
- Go toolchain: `1.25.9`
- Python 3 via Debian apt packages

## Formal Tooling Test Coverage

The formal validation scripts include dedicated end-to-end test coverage:

- `tests/scripts/ci/test_formal_validation_report_e2e.py`
- `tests/scripts/ci/test_formal_verification_bundle_e2e.py`
- `tests/scripts/ci/test_formal_validation_container_runner.py`

Run locally:

```bash
make validate-formal-tooling-tests
```

Coverage assertions include:

- deterministic report generation and strict `--check` mismatch failure
- bundle build integrity and tamper detection failure behavior
- container runner wiring (`docker build` + `docker run` invocation contract)

## CI Enforcement

Formal report and bundle checks are gated in:

- `.github/workflows/verify-formal-proofs.yml`
- `.github/workflows/verify-proofs.yml`
- `.github/workflows/full-validation-pr-gate.yml`

Formal artifact release publication is integrated in:

- `.github/workflows/release-assets.yml`

These workflows run the same scripts used locally.

## Reproducibility Notes

Toolchain locks are embedded in `results/proofs/formal_validation_report.json` under `toolchain_lock`:

- Lean toolchain pin from `proofs/lean-toolchain`
- Mathlib ref from `proofs/lakefile.lean`
- Go version from `go.mod`
- zk backend version pin (`github.com/consensys/gnark-crypto`) from `go.mod`

The report also includes deterministic `inputs` hashes and an `input_merkle_root` that ties the formal validation state to exact repository content.

Release packaging for external verifiers:

```bash
make package-formal-verification-artifacts
```

This writes:

- `release-assets/formal/formal_validation_report.json`
- `release-assets/formal/formal-verification-bundle.tar.gz`
- `release-assets/formal/bundle_manifest.json`
- `release-assets/formal/sha256sums.txt`
