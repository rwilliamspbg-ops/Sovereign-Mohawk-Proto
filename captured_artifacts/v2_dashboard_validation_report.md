# MOHAWK v2 Dashboard Validation Report

- Timestamp (UTC): 2026-03-26T23:43:58Z
- Grafana health: ok
- Prometheus health endpoint: Prometheus Server is Healthy.
- Prometheus rule API status: success

## Recording Rule Groups

- mohawk_v2_availability
- mohawk_v2_latency_quantiles
- mohawk_v2_rates

## Panel Expression Validation (All v2 Dashboards)

| Expression | Status | Series | Sample |
| --- | --- | ---: | --- |
| 1 - mohawk:gradient_submit:failure_rate_5m | success | 0 | no-data-idle-or-unemitted |
| count(up{job="node-agents"}) | success | 1 | 3 |
| histogram_quantile(0.50, sum by (le) (rate(mohawk_bridge_transfer_latency_ms_bucket[5m]))) | success | 1 | 0.05 |
| histogram_quantile(0.50, sum by (le) (rate(mohawk_proof_verification_latency_ms_bucket[5m]))) | success | 1 | 0.05 |
| histogram_quantile(0.95, sum by (le) (rate(mohawk_bridge_transfer_latency_ms_bucket[5m]))) | success | 1 | 0.09499999999999999 |
| histogram_quantile(0.95, sum by (le) (rate(mohawk_proof_verification_latency_ms_bucket[5m]))) | success | 1 | 0.095 |
| histogram_quantile(0.99, sum by (le) (rate(mohawk_bridge_transfer_latency_ms_bucket[5m]))) | success | 1 | 0.099 |
| histogram_quantile(0.99, sum by (le) (rate(mohawk_proof_verification_latency_ms_bucket[5m]))) | success | 1 | 0.099 |
| mohawk:accelerator_ops:rate1m | success | 1 | 0.44444246922359004 |
| mohawk:bridge_latency_ms:p95 | success | 1 | 0.09499999999999999 |
| mohawk:bridge_transfers:rate1m | success | 1 | 0.1111111111111111 |
| mohawk:gradient_submit:failure_rate_5m | success | 0 | no-data-idle-or-unemitted |
| mohawk:gradient_submit:rate1m | success | 1 | 0.11111012350068392 |
| mohawk:gradient_submit:success_rate_5m | success | 1 | 1 |
| mohawk:hybrid_proof_verifications:rate1m | success | 1 | 0.1111111111111111 |
| mohawk:node_agents_up:count | success | 1 | 3 |
| mohawk:orchestrator_up | success | 1 | 1 |
| mohawk:proof_latency_ms:p50 | success | 1 | 0.05 |
| mohawk:proof_latency_ms:p95 | success | 1 | 0.095 |
| mohawk:proof_latency_ms:p99 | success | 1 | 0.099 |
| mohawk:proof_verifications:rate1m | success | 1 | 0.17777777777777776 |
| mohawk:services_up:count | success | 1 | 6 |
| sum by (instance) (rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="failure"}[5m])) | success | 0 | no-data-idle-or-unemitted |
| sum by (instance) (rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="success"}[5m])) | success | 3 | 0.03508771929824561 |
| sum by (job) (up{job=~"orchestrator\|tpm-metrics\|node-agents\|pyapi-exporter"}) | success | 4 | 3 |
| sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="failure"}[5m])) | success | 0 | no-data-idle-or-unemitted |
| sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="success"}[5m])) | success | 1 | 0.0982456140350877 |
| sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit"}[5m])) | success | 1 | 0.0982456140350877 |
| sum(rate(mohawk_proof_verifications_total{result="failure"}[5m])) | success | 1 | 0.1964912280701754 |
| sum(rate(mohawk_proof_verifications_total{result="success"}[5m])) | success | 0 | no-data-idle-or-unemitted |
| up{job="node-agents"} | success | 3 | 1 |
| up{job=~"orchestrator\|tpm-metrics\|node-agents\|pyapi-exporter"} | success | 6 | 1 |

## Interpretation

- `status=success` for every expression confirms query correctness and metric-name alignment.
- `series=0` means idle workload or currently un-emitted label combinations, not a broken query.
- Availability expressions should be non-empty whenever scrape targets are up.
