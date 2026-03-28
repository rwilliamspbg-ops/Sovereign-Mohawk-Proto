# Windows TPM Attestation Evidence Capture Guide

## Objective

Capture Windows-host evidence required to close TPM attestation production readiness.

## Prerequisites

- Windows host with TPM 2.0 enabled.
- Repository checkout at release-candidate commit.
- Go toolchain aligned with project version.
- Administrative shell access for TPM inspection commands.

## Capture Steps

1. Record host/TPM details:
   - `Get-Tpm`
   - `Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer`
2. Run TPM-focused tests:
   - `go test ./test -run "TestGetVerifiedQuote|TestQuoteRoundTripWithXMSSMode|TestQuoteIncludesSignatureAlgorithm" -count=1`
3. Record replay/freshness behavior:
   - Run quote verify twice and capture expected replay handling output.
4. Save output log to:
   - `results/go-live/evidence/windows_tpm_validation_2026-03-28.md`

## Required Artifact Updates

- Update matrix entry in `results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json`:
  - `platform=windows`, `status=pass`, attach evidence path.
- Update attestation evidence list in `results/go-live/attestations/tpm_attestation_production_closure.json`.
- Re-run:
  - `python3 scripts/validate_tpm_attestation_closure.py`
  - `python3 scripts/generate_tpm_closure_summary.py`

## Output Template

Use `results/go-live/evidence/templates/tpm_platform_evidence_template.json` as the base schema.
