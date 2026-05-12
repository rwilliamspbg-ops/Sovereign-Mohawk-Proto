# Federated Intelligence Runbook

This runbook documents operator steps for monitoring, acknowledging, and remediating federated learning (FL) anomalies in the Ops Assistant.

## Overview

- The Ops Assistant exposes a Federated Intelligence Scoreboard under `/api/fl/intelligence/scoreboard` and a lightweight ops summary at `/api/ops/summary`.
- Prometheus metrics are available at `/metrics` (includes `sov_mohawk_federated_drift_score`, `sov_mohawk_federated_round_progress`, and `sov_mohawk_federated_anomalies_total`).

## Detecting Issues

1. Check the Ops Assistant UI sidebar for `Federated Intelligence` card.
2. If `Anomalies` > 0, open the scoreboard API or the UI anomaly list for details.

API example:

```
GET /api/fl/intelligence/scoreboard
```

## Acknowledge / Triage

Use the UI to `Acknowledge` an anomaly — this triggers `/api/fl/anomalies/ack` and increments an internal metric for tracking.

Operator steps for manual review:

1. Fetch contributor details from the scoreboard.
2. Isolate the node (remove from upcoming aggregation selection) if the anomaly is `high` severity.
3. Review attestation logs, TPM evidence, and zk-SNARK proofs where available.

## Remediation

- For `drift` anomalies: consider increasing verification weight before aggregation and rolling back node update if evidence suggests poisoning.
- For `poisoning` anomalies: exclude node and trigger a deep validation job.
- For `attestation` anomalies: pause aggregation and request manual attestation review.

## Metrics & Alerts

- Monitor `sov_mohawk_federated_drift_score` and create a recording rule/alert when > 0.5 for sustained windows.
- Alert when `sov_mohawk_federated_anomalies_total{severity="high"}` increases.
- Prometheus recording rules are available for:
	- `mohawk:federated_drift_score:avg5m`
	- `mohawk:federated_round_progress:avg5m`
	- `mohawk:federated_anomalies:increase5m`
	- `mohawk:federated_high_anomalies:increase5m`

## Contact & Escalation

- Pager: on-call ops team
- Slack: #federated-ops
- Include runbook steps taken and scoreboard JSON when escalating.
