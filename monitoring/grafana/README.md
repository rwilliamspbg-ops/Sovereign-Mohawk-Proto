# Sovereign Mohawk Grafana Dashboards

This directory contains production Grafana provisioning for the Sovereign Mohawk ecosystem.

## Purpose

These dashboards provide a role-based observability model:

- Operations Command: platform health, availability, and incident velocity.
- Security and Compliance: PQC posture, policy enforcement, and authorization pressure.
- Engineering Diagnostics: latency, node-agent behavior, and migration control-plane behavior.
- Executive Reporting: concise reliability and throughput KPIs with status at a glance.

## Provisioning Model

- Dashboards are loaded from `monitoring/grafana/dashboards`.
- Prometheus datasource is provisioned in `monitoring/grafana/provisioning/datasources/prometheus.yml`.
- Datasource UID is pinned to `grafana` to match dashboard references.

## Dashboard Set (v2)

- `v2-00-start-here.json`: Mission-control landing page and role navigation.
- `v2-10-ops-overview.json`: Golden signals and service-level health trends.
- `v2-11-ops-incidents.json`: Triage-first incident timeline and impact scope.
- `v2-12-security-pqc-compliance.json`: Security policy and PQC enforcement posture.
- `v2-20-eng-latency-drilldown.json`: Latency percentile and bottleneck drilldown.
- `v2-21-eng-node-agents.json`: Node-agent fleet status and quality metrics.
- `v2-22-eng-migration-control-plane.json`: Migration reliability and operational safety.
- `v2-30-exec-summary.json`: Executive KPI summary for service owners.

## Operating Guidance

- Use `v2-00-start-here.json` as the default home view.
- During incidents, move from `v2-10` to `v2-11`, then hand off to `v2-12` or engineering dashboards as needed.
- Anchor response actions to `OPERATIONS_RUNBOOK.md`.

## Quality Expectations

- Titles should be concise and audience-oriented.
- Panel descriptions should explain intent and decision value.
- Thresholds should map to SLOs and alerting rules in Prometheus.
