# TPM Closure Summary

- Generated (UTC): `2026-04-05T12:53:01+00:00`
- GA ready: `NO`
- Platform completion: `1/3 (33.33%)`
- Attestation status: `pending`

## Gate Status

- Advisory go-live gate: `PASS`
- Strict go-live gate: `FAIL`
- TPM closure validation: `FAIL`

## Platform Status

| Platform | Status | Evidence Count | Result |
| --- | --- | --- | --- |
| linux | pass | 1 | PASS |
| macos | pending | 0 | FAIL |
| windows | pending | 0 | FAIL |

## Remaining Failures

- platform not passing: windows status=pending
- platform missing evidence attachment: windows
- platform not passing: macos status=pending
- platform missing evidence attachment: macos
- attestation status is not approved: pending

## Evidence Inputs

- `results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json`
- `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.json`
- `results/go-live/evidence/go_live_gate_advisory_2026-03-28.json`
- `results/go-live/evidence/go_live_gate_strict_2026-03-28.json`
