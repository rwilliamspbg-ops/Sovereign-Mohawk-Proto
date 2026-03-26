# MOHAWK Dashboard v2 Guide

This guide defines the v2 observability layout so metrics are easy to find and interpret during operations, incidents, and performance analysis.

## Dashboard Map

- `v2-00-start-here.json`
  - Audience: all users
  - Purpose: fast orientation and navigation
- `v2-10-ops-overview.json`
  - Audience: operations
  - Purpose: service health, throughput, and latency baseline
- `v2-11-ops-incidents.json`
  - Audience: operations/on-call
  - Purpose: failure-centric triage and incident timelines
- `v2-20-eng-latency-drilldown.json`
  - Audience: engineering
  - Purpose: histogram quantile deep dive for proof and bridge paths
- `v2-21-eng-node-agents.json`
  - Audience: engineering
  - Purpose: per-agent availability and success/failure throughput
- `v2-30-exec-summary.json`
  - Audience: leadership
  - Purpose: high-level service status, reliability, and p95 latency trend

## Metric Naming

v2 dashboards primarily consume recorded series from `monitoring/prometheus/recording-rules.yml`:

- `mohawk:bridge_transfers:rate1m`
- `mohawk:proof_verifications:rate1m`
- `mohawk:hybrid_proof_verifications:rate1m`
- `mohawk:gradient_submit:rate1m`
- `mohawk:gradient_submit:failure_rate_5m`
- `mohawk:proof_latency_ms:p50`
- `mohawk:proof_latency_ms:p95`
- `mohawk:proof_latency_ms:p99`
- `mohawk:bridge_latency_ms:p50`
- `mohawk:bridge_latency_ms:p95`
- `mohawk:bridge_latency_ms:p99`
- `mohawk:services_up:count`
- `mohawk:node_agents_up:count`
- `mohawk:orchestrator_up`

## Validation Checklist

Run this checklist after deployment or dashboard edits:

1. Prometheus rules loaded: `curl -sf http://localhost:9090/api/v1/rules | jq '.status'`

1. Recorded metrics available:

  `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:gradient_submit:rate1m'`

  `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:proof_latency_ms:p95'`

  `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:services_up:count'`

1. Grafana panels render without query errors for all six v2 dashboards.

1. At least one panel in each dashboard shows non-empty data for active load periods.

## Troubleshooting

- If recorded metrics are missing:
  - confirm `rule_files` includes `/etc/prometheus/recording-rules.yml`
  - verify the compose mount for `recording-rules.yml`
  - check Prometheus logs for rule parse errors
- If panels are empty:
  - verify workload is running and exporters are healthy
  - inspect source series directly (for example `up`, `mohawk_accelerator_ops_total`)
  - widen time range to `Last 24 hours`
