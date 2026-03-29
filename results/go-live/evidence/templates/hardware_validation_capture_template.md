# Hardware Validation Capture Template

Use this template for each TPM/vTPM platform validation entry referenced in `HARDWARE_COMPATIBILITY.md`.

## Platform Metadata

- Validation date (UTC):
- Operator:
- Environment type: (bare metal / VM / cloud)
- Platform provider:
- Instance or host SKU:
- CPU model:
- OS + kernel:
- TPM vendor/firmware:
- Runtime mode:
  - `MOHAWK_TRANSPORT_KEX_MODE=`
  - `MOHAWK_TPM_IDENTITY_SIG_MODE=`

## Validation Window

- Soak duration:
- Start time:
- End time:

## Latency and Integrity Checks

1. Proof verification p95 (10m):
- Query: `histogram_quantile(0.95, sum(rate(mohawk_proof_verification_latency_ms_bucket[10m])) by (le))`
- Observed value:
- Pass/Fail against target:

1. Gradient submission latency p95 (10m):
- Query: `histogram_quantile(0.95, sum(rate(mohawk_accelerator_op_latency_ms_bucket{operation="gradient_submit"}[10m])) by (le))`
- Observed value:
- Pass/Fail against environment SLO:

1. TPM verification failures:
- Query: `increase(mohawk_tpm_verifications_total{result="failure"}[10m])`
- Observed value:
- Pass/Fail:

## Findings and Deviations

- Notable spikes or anomalies:
- KEX mismatch or key-size mismatch observations:
- Any fallback behavior observed:

## Evidence Attachments

- Readiness/metrics screenshot links:
- Raw query output location:
- Related incident ticket (if any):

## Sign-Off

- Runtime owner:
- Platform owner:
- Security owner:
- Final status: (verified / in-progress / blocked)
