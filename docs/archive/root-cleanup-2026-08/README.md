# Root Cleanup Archive Index — August 2026

This directory preserves the August 2026 root-cleanup batch (Pass 5 of the
relocation described in [../../ROOT_DOC_RELOCATION_PLAN.md](../../ROOT_DOC_RELOCATION_PLAN.md)).
Unlike Passes 1-4, this pass also covered executable scripts and stale
duplicate artifacts, not just documentation — see that plan's Pass 5 entry
for the full methodology and reference-check results. Nothing was deleted;
full git history is preserved for every file via `git mv`.

## What's here vs. what moved elsewhere

This folder holds files that are genuinely historical: one-off session
reports, commit-message drafts, phase-2 planning JSON, and stale/superseded
duplicates. Live tooling (scripts, one-off validation utilities) moved to
[`scripts/`](../../../scripts) instead, and the regenerable
`byzantine_10m_validation_report.json` moved to [`results/`](../../../results) —
neither belongs in an "archive" meant for dead material.

## Two stale duplicates worth flagging specifically

- **`FORMAL_TRACEABILITY_MATRIX.md`** — a root-level copy that had drifted
  from the canonical `proofs/FORMAL_TRACEABILITY_MATRIX.md` (last touched
  2026-05-05, vs. the real one which is actively maintained). Confirmed via
  grep that every CI workflow and script (`scripts/audit_theorem_dependencies.py`,
  `scripts/ci/generate_formal_proof_artifacts.sh`,
  `scripts/ci/generate_formal_validation_report.py`,
  `scripts/ci/lint_formal_proof_claims.py`,
  `scripts/ci/validate_formal_traceability.sh`, and the `working-directory: ./proofs`-scoped
  steps in `.github/workflows/verify-formal-proofs.yml` /
  `verify-proofs.yml`) reads the `proofs/` copy, not this one — it had zero
  live consumers.
- **`LeanFormalization/`** — a root-level directory containing *old* versions
  of `Theorem1BFT.lean`, `Theorem3Communication.lean`, and `Theorem4Liveness.lean`
  that differ from (and predate) the real, actively-built copies in
  `proofs/LeanFormalization/`. Same reference-check result: every real build
  step and script targets `proofs/LeanFormalization`. This one was actively
  risky to leave in place — a previous session's audit found and fixed several
  vacuous ("proves `True`", discards its own hypothesis) theorems in the real
  `proofs/LeanFormalization/Theorem1BFT.lean` and `Theorem4Liveness.lean`;
  this stale root copy still had the *pre-fix* vacuous versions, so anyone
  editing "the" `LeanFormalization/Theorem1BFT.lean` by guessing the path
  could easily have edited the wrong, dead copy.

## Inventory (alphabetical)

- [.ops-assistant-compose-fix.yml](.ops-assistant-compose-fix.yml)
- [CI_FAILURE_FIXES_OVERVIEW.txt](CI_FAILURE_FIXES_OVERVIEW.txt)
- [COMMIT_MSG_PR1.txt](COMMIT_MSG_PR1.txt)
- [COMMIT_MSG_PR3.txt](COMMIT_MSG_PR3.txt)
- [FINAL_DELIVERY_SUMMARY.txt](FINAL_DELIVERY_SUMMARY.txt)
- [FORMAL_TRACEABILITY_MATRIX.md](FORMAL_TRACEABILITY_MATRIX.md) — stale duplicate, see above
- [FORMAL_VALIDATION_EXECUTION_SUMMARY.txt](FORMAL_VALIDATION_EXECUTION_SUMMARY.txt)
- [LeanFormalization/](LeanFormalization/) — stale duplicate directory, see above
- [MERGE_VERIFICATION_COMPLETE.txt](MERGE_VERIFICATION_COMPLETE.txt)
- [QUICK_REFERENCE_CARD.txt](QUICK_REFERENCE_CARD.txt)
- [benchmark_results_phase2.txt](benchmark_results_phase2.txt)
- [benchmark_results_phase3.txt](benchmark_results_phase3.txt)
- [benchmark_results_phase4.txt](benchmark_results_phase4.txt)
- [demo_sovereign_mohawk.sh.txt](demo_sovereign_mohawk.sh.txt) — 0-byte stray file (accidental artifact, likely a typo'd `touch`), archived rather than silently dropped
- [go_analysis.txt](go_analysis.txt)
- [go_test_results.txt](go_test_results.txt)
- [mohawk_metrics.txt](mohawk_metrics.txt)
- [phase3_deployment_output.txt](phase3_deployment_output.txt)
- [phase_2_compression_config.json](phase_2_compression_config.json)
- [phase_2_deployment_playbook.json](phase_2_deployment_playbook.json)
- [phase_2_integration_code.json](phase_2_integration_code.json)

## Scripts and tools relocated to `scripts/` (not archived — still live)

`run_tests.sh`, `run_master_stress_tests.sh`, `complete-startup.sh`,
`fix-dashboard-uids.sh`, `fix-ops-assistant.sh`, `test_ci_workflow.sh`,
`test_documentation.sh`, `test_formal_proofs.py`, `analyze_tests.py`,
`convert_h5ad.py`, `create_test_dataset.py`, `phase_2_prepare.py`,
`comprehensive_local_tests.py`, `validation_test.py`,
`test_byzantine_validation_10m.py`, `genesis-launch.sh`, `run_lean_tests.ps1`,
and `test_byzantine_10m_validation.go` (moved to its own
`scripts/byzantine_10m_validation/` package directory, since Go doesn't allow
two `package main` files with conflicting declarations in the same
directory — `scripts/export_proofs.go` was already there).

Three of these scripts (`genesis-launch.sh`, `run_master_stress_tests.sh`,
`fix-ops-assistant.sh`) computed their own script directory via
`dirname "${BASH_SOURCE[0]}"` and `cd`'d into it, assuming that was the repo
root — true when they lived at root, false one level down in `scripts/`.
Fixed to `cd` to the parent directory instead. `genesis-launch.sh`'s
`COMPOSE_CMD` reference to a sibling script was updated the same way. The
Python and Go validation scripts wrote their JSON reports to a bare relative
filename (CWD-dependent); updated to write to `results/` explicitly so
re-running them doesn't recreate root clutter.

Every reference to these files in `.github/workflows/`, `Makefile`,
`README.md`, `CONTRIBUTING.md`, and `demo_sovereign_mohawk.sh` was found via
grep and updated to the new path before this commit landed — see the parent
commit for the full list (`Makefile`'s `local-validation-scripts` target,
`.github/workflows/release-assets.yml`'s testnet tarball step, and five
`./genesis-launch.sh` mentions across `README.md`/`CONTRIBUTING.md`/
`demo_sovereign_mohawk.sh`).

## Kept at root (not moved) despite looking like candidates

- `FORMAL_TRACEABILITY_MATRIX.md`'s canonical copy lives at `proofs/` (not archived — that one's current).
- `TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md`, `BLOG_POST_FORMAL_PROOFS.md` — read by `scripts/ci/lint_formal_proof_claims.py`'s `protected_docs` list at their root paths.
- `VALIDATION_SIGN_OFF.md` — read by `scripts/comprehensive_local_tests.py`'s file-completeness check at its root path.
- `bridge-policies.json`, `capabilities.json` — read by multiple workflows and scripts at their root paths.
- `setup.sh`, `SETUP_ENVIRONMENT.ps1`, `QUICK_START.bat`, `CHECK_ENVIRONMENT.bat`, `DOWNLOAD_GO.bat`, `INSTALL_DEPENDENCIES.bat`, `demo_sovereign_mohawk.sh` — kept as legitimate root-level onboarding/demo entrypoints (the pattern a new contributor expects to find at the top of the repo), not one-off session artifacts.
- `index.html` — has a `google-site-verification` meta tag and full landing-page markup; left at root on the assumption GitHub Pages may be configured to serve it from there (not verifiable from the repo alone — confirm in repo Settings before moving this one).
- Docker/compose files (`Dockerfile*`, `docker-compose*.yml`) — left at root per standard convention and the existing `ROOT_DOC_RELOCATION_PLAN.md` guidance that these need root-relative build contexts.

## Reference-check methodology

Same as Pass 4, extended to cover executable scripts (previous passes were
explicitly scoped to "documentation-only" to limit risk — see that pass's
notes): for every candidate, grep'd `.github/`, `scripts/`, `Makefile`,
`docker-compose*.yml`, `.pre-commit-config.yaml`, `Dockerfile*`, and the
top-level docs for the bare filename, then read the matching context to
determine whether it was a real root-relative dependency (fix and keep, or
fix and move) versus an unrelated match (e.g. `proofs/FORMAL_TRACEABILITY_MATRIX.md`
also containing the substring `FORMAL_TRACEABILITY_MATRIX.md`) or a
`working-directory:`-scoped step in a GitHub Actions job that changes what a
bare relative path in that step actually resolves to.
