# FIPS Evidence Bundle (2026-04-05)

## Runtime FIPS Enforcement

- Startup gate implementation: `internal/startup/fips.go`
- Orchestrator wiring: `cmd/orchestrator/main.go`
- Runtime check command: `make fips-runtime-check`

## Regression Test Evidence

- Test target: `make fips-regression`
- Test file: `test/fips_regression_test.go`
- Covered flows:
  - TLS handshake path
  - ECDSA P-256 key generation
  - ECDSA signing and verification

## Governance and Boundary Inventory

- Scope and module inventory: `FIPS_PROFILE_SCOPE.md`
- Runbook operator posture: `OPERATIONS_RUNBOOK.md`
- Release gate requirement: `RELEASE_CHECKLIST_v1.0.0_RC.md`

## Notes

This bundle captures in-repository FIPS controls and test evidence requirements. External certification or lab validations are tracked separately via organizational compliance processes.
