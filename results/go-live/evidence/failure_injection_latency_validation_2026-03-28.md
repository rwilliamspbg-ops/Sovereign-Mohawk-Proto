# Failure-Injection Latency Validation (2026-03-28)

- Generated (UTC): `2026-04-05T12:53:01+00:00`
- Baseline version: `v1.0.0-rc1`
- Overall result: `PASS`

## Scenario Results

| Scenario | Latency | Threshold | Gate OK | Threshold OK | Overall | Artifact |
| --- | --- | --- | --- | --- | --- | --- |
| grafana | 4s | 120s | yes | yes | PASS | `chaos-reports/grafana-summary.json` |
| orchestrator | 8s | 120s | yes | yes | PASS | `chaos-reports/orchestrator-summary.json` |
| prometheus | 21s | 120s | yes | yes | PASS | `chaos-reports/prometheus-summary.json` |
| tpm-metrics | 9s | 90s | yes | yes | PASS | `chaos-reports/tpm-metrics-summary.json` |

## Gate Checks

- `readiness_gate_ok`: PASS
- `chaos_scenarios_found`: PASS
- `all_scenarios_within_threshold`: PASS

## Failures

- none
