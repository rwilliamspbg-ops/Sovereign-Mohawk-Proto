# TPM Attestation Windows Validation Template

Status: pending

## Required Checks

- TPM 2.0 quote generation succeeds in production mode.
- TPM quote verification succeeds with replay protection checks.
- Attestation envelope includes expected signature metadata.

## Command Capture

- Build and run attestation validation command(s) on a Windows host.
- Capture output, environment details, and timestamp.

## Evidence Attachments

- Host details (Windows version, TPM provider details)
- Command output transcript
- Result summary (pass/fail)

## Signoff

- Owner:
- Date (UTC):
- Notes:
