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

## Host Kernel UDP/Socket Buffer Checklist (Production)

Production one-click execution defaults to strict host preflight (`MOHAWK_HOST_PREFLIGHT_MODE=strict`).

Required minimums:

- `net.core.rmem_max=8388608`
- `net.core.rmem_default=262144`
- `net.core.wmem_max=8388608`
- `net.core.wmem_default=262144`

Apply immediately (root required):

- `sudo sysctl -w net.core.rmem_max=8388608`
- `sudo sysctl -w net.core.rmem_default=262144`
- `sudo sysctl -w net.core.wmem_max=8388608`
- `sudo sysctl -w net.core.wmem_default=262144`

Persist across reboots:

1. Add the keys above to `/etc/sysctl.conf` or `/etc/sysctl.d/99-mohawk-network.conf`
2. Apply persisted settings: `sudo sysctl --system`

Development-only override (non-production):

- `MOHAWK_HOST_PREFLIGHT_MODE=advisory make mainnet-one-click`

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

## Quantum Migration Cutover (Dual-Signature)

### Recommended Epoch Controls

Set these defaults in deployment profiles:

- `MOHAWK_PQC_MIGRATION_EPOCH=2027-12-31T00:00:00Z`
- `MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH=true`

At or after migration epoch, boolean dual-signature flags are rejected for migration transfers and cryptographic signatures are required.

### Generate Canonical Signing Digest

Request the digest from orchestrator (admin-authenticated):

- `POST /ledger/migration/digest`

Example:

```bash
curl -fsS -X POST https://localhost:8080/ledger/migration/digest \
   -H "Authorization: Bearer $(cat runtime-secrets/mohawk_api_token)" \
   -H "Content-Type: application/json" \
   -d '{
      "legacy_account":"legacy-edge",
      "pqc_account":"mldsa-edge",
      "amount":2.5,
      "memo":"migration-wave-1",
      "idempotency_key":"mig-legacy-edge-001",
      "nonce":101
   }'
```

Response includes `digest_hex` and `amount_units`.

### Submit Cryptographic Migration Transfer

Submit both signatures to `POST /ledger/migration/migrate`:

```json
{
   "legacy_account": "legacy-edge",
   "pqc_account": "mldsa-edge",
   "amount": 2.5,
   "memo": "migration-wave-1",
   "idempotency_key": "mig-legacy-edge-001",
   "nonce": 101,
   "legacy_algo": "ecdsa-p256-sha256",
   "legacy_pub_key": "<base64-or-pem>",
   "legacy_sig": "<base64-or-hex-or-pem>",
   "pqc_algo": "ml-dsa-65",
   "pqc_pub_key": "<base64-or-pem>",
   "pqc_sig": "<base64-or-hex-or-pem>"
}
```

Accepted PQC algorithm aliases currently include `ml-dsa`, `ml-dsa-44`, `ml-dsa-65`, `ml-dsa-87`, and `mldsa`.

## Evidence Sources

- `results/readiness/readiness-digest.md`
- `results/readiness/readiness-report.json`
- `chaos-reports/*`
- `test/utility_coin_durability_test.go`
- `internal/token/ledger.go`
- `internal/pyapi/api.go`
