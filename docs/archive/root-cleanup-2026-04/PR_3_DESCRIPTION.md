# PR #3: Phase 4 PQC Migration Formal Refinements and Traceability Validation

## Summary

This PR strengthens the Lean-to-Go formalization for PQC migration safety and updates validation artifacts so reviewers can trace theorem claims to runtime behavior and tests.

Primary outcomes:

- Stronger non-tautological refinement lemmas for migration and settlement paths.
- Shared migration/UF-CMA structures centralized in common Lean definitions.
- Updated formal traceability and generated validation report artifacts.
- PR template enhanced with proof/validation checklist guidance.

## Scope of Changes

### Formalization

- Centralized shared definitions in `proofs/LeanFormalization/Common.lean`:
  - `LegacySig`, `PQCSig`, `SignOracle`, `Adversary`
  - `ufCmaWins`, `pqcUnforgeable`
  - `MigrationAuth`, `MigrationPhase`, `LedgerState`
  - `postEpochAccepts`, `hijackSafe`
- Tightened theorem refinements in:
  - `proofs/LeanFormalization/Theorem7PQCMigrationContinuity.lean`
  - `proofs/LeanFormalization/Theorem8DualSignatureNonHijack.lean`
- Minor tactic hygiene and unused-arg cleanup in:
  - `proofs/LeanFormalization/Theorem5Cryptography.lean`

### Traceability and Evidence

- Updated theorem/runtime mapping and validation run record in:
  - `proofs/FORMAL_TRACEABILITY_MATRIX.md`
- Updated formal audit summary coverage in:
  - `proofs/FULL_FORMALIZATION_VALIDATION_REPORT.md`
- Regenerated machine-checkable report:
  - `results/proofs/formal_validation_report.json`

### Runtime Linkage Docs

- Added linkage note in Go settlement path:
  - `internal/token/settlement.go`
- Added audit template addendum for Theorem 7/8 evidence:
  - `proofs/audit_verification.md`

### PR Process Improvements

- Expanded `.github/PULL_REQUEST_TEMPLATE.md` with:
  - proof/validation context
  - relation to PR #48
  - explicit Lean build/validation checklist
  - benchmark note section

## Contributor Guide Compliance

Reference: `CONTRIBUTING.md`

### Required checks run

- `make lint`
- `make black`
- `cd proofs && /home/codespace/.elan/bin/lake build`
- `bash scripts/ci/validate_formal_traceability.sh`
- `/workspaces/Sovereign-Mohawk-Proto/.venv/bin/python scripts/ci/generate_formal_validation_report.py`
- `/workspaces/Sovereign-Mohawk-Proto/.venv/bin/python scripts/ci/generate_formal_validation_report.py --check`

### Results

- `make lint`: completed (note: Makefile target is non-blocking and reports missing global `ruff` module in this environment).
- `make black`: completed; `sdk/python` formatting check reported unchanged files.
- Lean build: pass.
- Traceability validation: pass (`8` modules, `48` theorem symbols, `20` runtime test references).
- Formal validation report: regenerated and `--check` pass.

### Test Status

- `make test`: blocked in this environment because docker compose service `orchestrator` is not running.
- Host fallback executed: `GOTOOLCHAIN=go1.25.9+auto go test ./...` and passed.

## Risk and Compatibility

- No protocol behavior changes in this PR.
- Changes are formalization, traceability, and documentation focused.
- Runtime code impact is limited to a policy-linkage comment in settlement.

## Reviewer Checklist

- [ ] Verify centralized Common definitions are imported and used by Theorem 7/8.
- [ ] Verify refinement lemmas now encode field-level Go gate implications.
- [ ] Verify traceability matrix rows 8/9 match theorem symbols and runtime tests.
- [ ] Verify regenerated `results/proofs/formal_validation_report.json` is included.
- [ ] Confirm no unexpected runtime behavior changes.

## Suggested Commit Plan

```bash
git add \
  .github/PULL_REQUEST_TEMPLATE.md \
  internal/token/settlement.go \
  proofs/LeanFormalization/Common.lean \
  proofs/LeanFormalization/Theorem5Cryptography.lean \
  proofs/LeanFormalization/Theorem7PQCMigrationContinuity.lean \
  proofs/LeanFormalization/Theorem8DualSignatureNonHijack.lean \
  proofs/FORMAL_TRACEABILITY_MATRIX.md \
  proofs/FULL_FORMALIZATION_VALIDATION_REPORT.md \
  proofs/audit_verification.md \
  results/proofs/formal_validation_report.json \
  PR_3_DESCRIPTION.md

git commit -F COMMIT_MSG_PR3.txt
git push origin feat/planning-doc-and-validation-scripts
```

## Notes for Maintainers

- There is an untracked directory in this workspace (`Sovereign-Mohawk-Proto-pr/`) that is not part of this PR scope.
- If desired, we can add or update `.gitignore` in a follow-up PR to avoid accidental staging of that directory.
