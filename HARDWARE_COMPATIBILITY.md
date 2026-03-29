# Hardware Compatibility and Validation Matrix

This document tracks TPM/HSM compatibility for XMSS-attested identity flows and confirms whether platforms stay inside the proof-verification latency guardrails used by Sovereign-Mohawk operations.

## Why this exists

Sovereign-Mohawk defaults to:

- `MOHAWK_TRANSPORT_KEX_MODE=x25519-mlkem768-hybrid`
- `MOHAWK_TPM_IDENTITY_SIG_MODE=xmss`

The platform target for proof checks is near the 10 ms validation envelope. Operators need a reproducible matrix to verify that TPM/HSM-backed signing and attestation do not push validation paths beyond SLO.

## Validation Criteria

A platform is considered release-compatible when all checks pass:

1. Attestation integrity:

- TPM quote generation and verification pass without fallback.
- XMSS identity mode is accepted end-to-end.

1. Latency SLO:

- `mohawk_proof_verification_latency_ms` p95 <= 10 ms over 10-minute soak.
- `mohawk_accelerator_op_latency_ms{operation="gradient_submit"}` p95 stays within environment SLO.

1. Stability:

- No sustained `mohawk_tpm_verifications_total{result="failure"}` growth.
- No sustained KEX mismatch rejections during rounds.

## Compatibility Status Legend

- `verified`: Evidence captured and checked into repo artifacts.
- `in-progress`: Test plan exists; artifact capture pending.
- `not-started`: No validated run recorded.

## TPM / HSM Matrix

| Platform | Class | XMSS Mode | 10 ms zk-SNARK Window | Status | Evidence / Notes |
| --- | --- | --- | --- | --- | --- |
| `swtpm` (containerized CI/dev) | Software TPM 2.0 | Supported in runtime config | Measured in local and CI smoke flows; use as baseline only | verified | `results/go-live/evidence/tpm_attestation_closure_validation_2026-03-28.md`, `results/go-live/evidence/tpm_attestation_local_sandbox_2026-03-29.md` |
| Discrete TPM 2.0 (Infineon/Intel/STM class chips) | Physical TPM 2.0 | Expected supported | Must be measured per host SKU/firmware | in-progress | Track with capture templates in `results/go-live/evidence/templates/` |
| AWS NitroTPM (EC2 Nitro instances) | Cloud TPM-backed host identity | Expected supported | Validate under production load profile | in-progress | Capture with runbook procedure and store in `results/go-live/evidence/` |
| GCP Shielded VM vTPM | Cloud vTPM | Expected supported | Validate under production load profile | in-progress | Capture with runbook procedure and store in `results/go-live/evidence/` |
| Azure Trusted Launch vTPM | Cloud vTPM | Expected supported | Validate under production load profile | not-started | Add evidence file after first soak run |

## Required Evidence Bundle per Hardware Target

For each hardware target, commit or archive:

1. Host profile:

- CPU model, TPM firmware, kernel version, cloud instance type.

1. Validation report:

- 10-minute metrics capture for proof and gradient submission latency.
- TPM verification success/failure counts.

1. Artifacts:

- `results/go-live/evidence/tpm_attestation_<platform>_<date>.md`
- Optional raw metric snapshots under `captured_artifacts/`.
- Start from template: `results/go-live/evidence/templates/hardware_validation_capture_template.md`

## Operator Validation Procedure

1. Launch stack:

```bash
./scripts/launch_full_stack_3_nodes.sh --no-build
```

1. Confirm attestation and quote path:

```bash
curl -sfG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=increase(mohawk_tpm_verifications_total{result="failure"}[10m])'
```

1. Confirm proof latency window:

```bash
curl -sfG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(mohawk_proof_verification_latency_ms_bucket[10m])) by (le))'
```

1. Confirm gradient submission latency:

```bash
curl -sfG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(mohawk_accelerator_op_latency_ms_bucket{operation="gradient_submit"}[10m])) by (le))'
```

1. Save evidence and update this matrix.

## Notes on Cloud HSM vs TPM

Cloud HSM offerings and TPM/vTPM solve related but distinct problems. This runtime currently binds identity and attestation to TPM-style quote workflows. If Cloud HSM is used for additional signing controls, document it as an additive control in the same evidence bundle with explicit latency impact measurements.

## Related Release Evidence

- Consolidated release-candidate evidence index:
  - `results/go-live/evidence/release_candidate_evidence_checkpoint_2026-03-29.md`
