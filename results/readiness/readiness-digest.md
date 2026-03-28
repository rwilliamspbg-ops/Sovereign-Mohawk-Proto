# Weekly Mainnet Readiness Digest

Automated summary generated from readiness and chaos gate runs.

## Readiness Gate

- Status: ✅ pass
- Failures: none

### Check Results

| Check | Value |
| --- | --- |
| bridge_transfers_min_activity | true |
| bridge_transfers_non_negative | true |
| bridge_transfers_series_present | true |
| grafana_health | true |
| hybrid_proof_min_activity | true |
| hybrid_proof_non_negative | true |
| hybrid_proof_series_present | true |
| metric_names_present | true |
| prometheus_api | true |
| proof_verifications_min_activity | true |
| proof_verifications_non_negative | true |
| proof_verifications_series_present | true |
| supply_invariant | true |
| targets_up | true |
| tpm_attestation_signature_mode | true |
| tpm_health | true |
| tx_count_non_negative | true |

## Chaos Gate

| Scenario | Baseline | Outage Failure Expected | Recovery | Recovery Latency | Threshold | Latency SLO |
| --- | --- | --- | --- | --- | --- | --- |
| grafana | ✅ | ✅ | ✅ | 4s | 120s | ✅ |
| orchestrator | ✅ | ✅ | ✅ | 8s | 120s | ✅ |
| prometheus | ✅ | ✅ | ✅ | 21s | 120s | ✅ |
| tpm-metrics | ✅ | ✅ | ✅ | 9s | 90s | ✅ |
