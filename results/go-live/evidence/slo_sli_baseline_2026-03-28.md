# SLO/SLI Baseline (2026-03-28)

## Version

- Baseline version: `v1.0.0-rc1`
- Owner: platform-engineering
- Scope: Phase 3 v1.0.0 GA closure

## SLI Definitions

| SLI | Description | Evidence Source | Target |
| --- | --- | --- | --- |
| readiness_gate_ok | Overall readiness gate health | `results/readiness/readiness-report.json` (`ok`) | `true` for each release-candidate run |
| recovery_latency_seconds | Recovery latency during chaos/failure injection | `chaos-reports/*-summary.json` (`recovery_latency_seconds`) | At or below scenario threshold |
| proof_latency_p95_ms | Proof verification p95 latency | Prometheus query `mohawk:proof_latency_ms:p95` | `< 100ms` under normal load |

## SLO Targets

- Readiness gate must pass (`ok=true`) for release-candidate and GA sign-off.
- Recovery latency thresholds:
  - `grafana`: <= 120s
  - `orchestrator`: <= 120s
  - `prometheus`: <= 120s
  - `tpm-metrics`: <= 90s
- Proof latency p95 target: `< 100ms`.

## Evaluation Policy

- Evaluate on every release-candidate cycle and weekly readiness digest run.
- Required evidence set:
  - `results/readiness/readiness-report.json`
  - `results/readiness/readiness-digest.md`
  - `chaos-reports/grafana-summary.json`
  - `chaos-reports/orchestrator-summary.json`
  - `chaos-reports/prometheus-summary.json`
  - `chaos-reports/tpm-metrics-summary.json`
- Any threshold violation blocks GA promotion until remediation evidence is attached.
