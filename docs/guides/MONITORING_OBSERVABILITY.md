# Monitoring and Observability — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Stack

- Prometheus: `monitoring/prometheus/` (scrape configs).
- Grafana: `monitoring/grafana/` (dashboards).
- Alertmanager: `monitoring/alertmanager/`.

## 2. Key metrics

| Metric | Source | Purpose |
|---|---|---|
| Proof verification latency | ZK verifier | SLA tracking |
| Aggregation latency | federation aggregator | Tier performance |
| Attestation success rate | TPM path | Identity health |
| Straggler timeout rate | federation | Sabotage detection |
| RDP budget spend | RDP accountant | Privacy compliance |

## 3. Dashboards

Grafana dashboards under `monitoring/grafana/`. Import via the Grafana
provisioning config.

## 4. Alerting rules

Prometheus alerting rules under `monitoring/prometheus/`. Alertmanager
routing under `monitoring/alertmanager/`.

## 5. Cross-references

- Operations: `docs/guides/OPERATIONS.md`
- Troubleshooting: `docs/guides/TROUBLESHOOTING.md`
