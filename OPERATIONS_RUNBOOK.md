# Operations Runbook

## Scope

This runbook covers production operations for the Sovereign Mohawk protocol stack:

- readiness and chaos gating
- incident response and escalation
- backup/restore controls for utility ledger
- host network preflight expectations

## Daily / Release Preflight

1. Run strict readiness gate:
   - `python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 --min-bridge-transfers 1 --min-proof-verifications 1 --min-hybrid-verifications 1`
2. Run chaos drills:
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh tpm-metrics chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh orchestrator chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh prometheus chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh grafana chaos-reports`
3. Verify host kernel tuning:
   - `./scripts/validate_host_network_tuning.sh`

## Incident Escalation

### Severity Levels

- **SEV-1:** Readiness gate hard fail in production or sustained chaos recovery SLO breach.
- **SEV-2:** Repeated metric/target instability with successful recovery.
- **SEV-3:** Advisory-only warnings (e.g., CI host preflight advisory).

### Escalation Flow

1. Triage on-call reviews latest:
   - `results/readiness/readiness-report.json`
   - `chaos-reports/*-summary.json`
2. If SEV-1/SEV-2:
   - Trigger chat notification path via weekly digest workflow integrations.
   - Open incident issue with attached readiness/chaos artifacts.
3. Assign owners:
   - Runtime owner (orchestrator/node-agent)
   - Platform owner (Prometheus/Grafana/host tuning)
   - Security owner (if auth, threat, or policy failure)

## Backup / Restore Drill Procedure

1. Generate backup with authorized admin role.
2. Restore from backup in controlled environment.
3. Verify ledger state and migration controls remain coherent.
4. Preserve evidence in test artifacts and attestation files.

## Evidence Sources

- `results/readiness/readiness-digest.md`
- `results/readiness/readiness-report.json`
- `chaos-reports/*`
- `test/utility_coin_durability_test.go`
- `internal/token/ledger.go`
- `internal/pyapi/api.go`
