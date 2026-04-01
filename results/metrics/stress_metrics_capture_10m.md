# 10-Minute Stress Metrics Capture

- Start (UTC): 2026-04-01T00:31:17.285815+00:00
- End (UTC): 2026-04-01T00:41:17.285940+00:00
- Duration seconds: 600

| Signal | PromQL | Value |
| --- | --- | --- |
| honest_ratio_min_10m | `min_over_time(mohawk_consensus_honest_ratio[10m])` | `NA` |
| gradient_failure_ratio_5m | `(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="failure"}[5m]))/clamp_min(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit"}[5m])),1e-9))` | `1` |
| proof_p95_ms_10m | `histogram_quantile(0.95, sum(rate(mohawk_proof_verification_latency_ms_bucket[10m])) by (le))` | `0.095` |
| tpm_failures_increase_10m | `increase(mohawk_tpm_verifications_total{result="failure"}[10m])` | `NA` |
| bridge_transfer_rate_5m | `sum(rate(mohawk_bridge_transfers_total[5m]))` | `0.10175438596491226` |
| hybrid_verifications_10m | `sum(increase(mohawk_proof_verifications_total{scheme="hybrid"}[10m]))` | `60.51282051282051` |
| compression_observations_10m | `sum(increase(mohawk_gradient_compression_ratio_count[10m]))` | `60.51282051282051` |

Notes: values captured from live local stack after continuous 10-minute window.
