# TPM Attestation Cross-Platform Validation Matrix (2026-03-28)

## Scope

This matrix tracks closure evidence for TPM attestation production mode across Linux, Windows, and macOS.

## Required Validation Criteria

- TPM 2.0 quote generation and verification path validated.
- Replay protection validation completed (signature index/nonces).
- Attestation evidence payload includes required fields and signature metadata.
- Production mode attestation checks exercised.

## Platform Matrix

| Platform | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Linux | PASS | `results/go-live/evidence/tpm_attestation_linux_validation_2026-03-28.md` | Executed in repository environment with TPM quote/verify test coverage. |
| Windows | PENDING | n/a | Validation run and evidence pending. |
| macOS | PENDING | n/a | Validation run and evidence pending. |

## Closure Rule

This item is considered fully complete only when all three platforms are `PASS` and evidence is attached for each.
