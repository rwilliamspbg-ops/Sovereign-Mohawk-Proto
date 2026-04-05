# TPM Attestation Production Closure Validation

- Generated (UTC): `2026-04-05T13:34:01+00:00`
- Overall result: `FAIL`

## Platform Status

| Platform | Present | Status | Evidence Count | Result |
| --- | --- | --- | --- | --- |
| linux | yes | pass | 1 | PASS |
| windows | yes | pending | 0 | FAIL |
| macos | yes | pending | 0 | FAIL |

## Checks

- `all_platforms_present`: PASS
- `all_platforms_pass`: FAIL
- `all_platforms_have_evidence`: FAIL
- `attestation_approved`: FAIL

## Failures

- platform not passing: windows status=pending
- platform missing evidence attachment: windows
- platform not passing: macos status=pending
- platform missing evidence attachment: macos
- attestation status is not approved: pending
