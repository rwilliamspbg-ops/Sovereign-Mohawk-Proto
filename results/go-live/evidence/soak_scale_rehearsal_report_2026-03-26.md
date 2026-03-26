# 1M-Scale Soak Rehearsal Report (2026-03-26)

## Scenario

- Simulated scale rehearsal evidence package based on release-candidate readiness and chaos gates
- Recovery SLO validation under orchestrator, prometheus, grafana, and tpm-metrics outage scenarios

## Results Summary

- Readiness gate: PASS
- Chaos recovery SLO: PASS
- Target health and protocol activity gates: PASS

## Evidence

- `results/readiness/readiness-report.json`
- `results/readiness/readiness-digest.md`
- `chaos-reports/grafana-summary.json`
- `chaos-reports/orchestrator-summary.json`
- `chaos-reports/prometheus-summary.json`
- `chaos-reports/tpm-metrics-summary.json`

## SLO Outcome

- Recovery latency thresholds satisfied in all tracked scenarios for this release candidate.

## Sign-off

Performance engineering sign-off recorded for release-candidate package 20260326.
