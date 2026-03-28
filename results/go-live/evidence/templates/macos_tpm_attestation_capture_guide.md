# macOS TPM Attestation Evidence Capture Guide

## Objective

Capture macOS evidence and fallback policy details for TPM attestation closure.

## Policy Context

macOS has no native TPM 2.0 device path equivalent to standard Linux/Windows TPM flows. Evidence must explicitly state fallback mode and controls used.

## Prerequisites

- macOS host (or VM with virtual TPM if available).
- Repository checkout at release-candidate commit.
- Go toolchain aligned with project version.

## Capture Steps

1. Record host details:
   - `sw_vers`
   - `sysctl -n machdep.cpu.brand_string`
2. Record attestation mode/fallback controls:
   - `echo "$MOHAWK_TPM_IDENTITY_SIG_MODE"`
   - Document whether virtual TPM is used or software fallback policy is active.
3. Run TPM-focused tests:
   - `go test ./test -run "TestGetVerifiedQuote|TestQuoteRoundTripWithXMSSMode|TestQuoteIncludesSignatureAlgorithm" -count=1`
4. Save output log to:
   - `results/go-live/evidence/macos_tpm_validation_2026-03-28.md`

## Required Artifact Updates

- Update matrix entry in `results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-03-28.json`:
  - `platform=macos`, set status and evidence path.
- Update attestation evidence list in `results/go-live/attestations/tpm_attestation_production_closure.json`.
- Re-run:
  - `python3 scripts/validate_tpm_attestation_closure.py`
  - `python3 scripts/generate_tpm_closure_summary.py`

## Output Template

Use `results/go-live/evidence/templates/tpm_platform_evidence_template.json` as the base schema.
