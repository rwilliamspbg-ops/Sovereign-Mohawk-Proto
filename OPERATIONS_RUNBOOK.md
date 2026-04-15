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
   - `sudo bash scripts/host_tuning.sh --persist`
4. Validate formal go-live gate:
   - Strict production mode: `python3 scripts/validate_go_live_gates.py --host-preflight-mode strict`
   - Advisory non-production mode: `python3 scripts/validate_go_live_gates.py --host-preflight-mode advisory`

## Day 2 Recovery Drills

### Quantum KEX Rotation Drill (No Global Drop)

Run staged KEX policy rotation with rolling restarts:

1. Dry run:
   - `bash scripts/quantum_kex_rotation_drill.sh --mode x25519-mlkem768-hybrid --dry-run`
2. Execute rolling drill:
   - `bash scripts/quantum_kex_rotation_drill.sh --mode x25519-mlkem768-hybrid`
3. Optional custom order:
   - `bash scripts/quantum_kex_rotation_drill.sh --services node-agent-1,node-agent-2,node-agent-3,orchestrator`

Operational notes:

- Keep restarts one service at a time.
- Watch gradient failure ratio during rotation to ensure aggregate availability remains within SLO.
- If mismatch rejections spike, complete remaining restarts quickly to converge all services on one KEX mode.

### Byzantine Forensics Extraction Drill

Generate an auditable report of rejected gradient submissions:

1. Capture the last 30 minutes:
   - `bash scripts/extract_byzantine_forensics.sh --since 30m`
2. Capture a longer window with explicit output path:
   - `bash scripts/extract_byzantine_forensics.sh --since 2h --output results/forensics/byzantine_rejections_2h.md`
3. Correlate with resilience metrics:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=min_over_time(mohawk_consensus_honest_ratio[10m])' | jq '.'`

Threat-intel workflow:

- Attach report output from `results/forensics/` to the incident issue.
- Compare rejection categories (mode mismatch, unsupported mode, submission errors) against expected adversarial budget.
- Escalate to SEV-1 if rejection trends coincide with sustained honest-ratio threshold breaches.

### Byzantine Rejection Triage Matrix

| Rejection Signal | Primary Owner | First Action | Escalation Trigger |
| --- | --- | --- | --- |
| `accepted=false` | Runtime owner | Pull top rejection lines and correlate with round/task IDs | > threshold in two consecutive runs |
| `KEX mismatch` / `unsupported kex mode` | Platform owner | Run `scripts/quantum_kex_rotation_drill.sh` and normalize transport mode | Persistent mismatch after completed rolling convergence |
| `submission failed` | Runtime + Platform | Inspect node-agent connectivity, orchestrator stream handler logs, and relay path | Failure ratio remains elevated for >10m |
| `kex public key bytes mismatch` | Security owner | Validate negotiated mode key-size expectations and recent policy changes | Any recurrence after policy rollback |

Use this matrix with `results/forensics/byzantine_forensics_delta.md` to classify whether drift is policy/config, transport, or adversarial.

## Observability v2 Validation

Run this after Prometheus/Grafana changes or before release sign-off.

1. Ensure stack is running:
   - `./scripts/launch_full_stack_3_nodes.sh --no-build`
2. Confirm Prometheus has loaded recording rules:
   - `curl -sf http://localhost:9090/api/v1/rules | jq '.status'`
3. Confirm key recorded metrics are queryable:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:gradient_submit:rate1m'`
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:proof_latency_ms:p95'`
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=mohawk:services_up:count'`
4. Open Grafana and validate all v2 dashboards render without panel query errors:
   - `http://localhost:3000`
5. Save verification evidence:
   - `results/metrics/v2_dashboard_validation_report.md`

## Tamper-Evident Event Export (Deployer Audit Bundle)

Run this to export chained, tamper-evident event logs for key controls (aggregation, zk verification, Byzantine checks, privacy budget policy guard):

1. Generate export bundle from live metrics and ledger audit chain status:
   - `python3 scripts/export_tamper_evident_events.py --prom-url http://localhost:9090 --output-dir results/forensics/tamper-evident-events`
2. Verify output artifacts are present:
   - `results/forensics/tamper-evident-events/events.ndjson`
   - `results/forensics/tamper-evident-events/events_chained.ndjson`
   - `results/forensics/tamper-evident-events/bundle_manifest.json`
   - `results/forensics/tamper-evident-events/tamper_evident_events_bundle.tar.gz`
3. Archive the tarball with release or incident evidence bundles.

## Alert Routing (Critical and Warning)

Alertmanager is wired in compose and Prometheus alerting config.

1. Start alerting stack:
   - `docker compose up -d alertmanager prometheus`
2. Validate Alertmanager API health:
   - `curl -sf http://localhost:9093/-/healthy`
3. Validate Prometheus has active alertmanager target:
   - `curl -sf http://localhost:9090/api/v1/alertmanagers | jq '.'`
4. Receiver mapping in this repository:
   - `severity=critical` -> `critical-route`
   - `severity=warning` -> `warning-route`
   - default -> `default-sink`

## Benchmark Regression Playbook

Run benchmark checks before release cut or after aggregation/runtime changes.

Policy baseline:

- FedAvg PR gate fails if geomean time regression exceeds `+5.0%` relative to cached `main` baseline.
- Bridge PR gate fails if geomean time regression exceeds `+5.0%` relative to cached `main` baseline.
- Python SDK gate enforces absolute thresholds and trend regression limits when cached baseline data is available.

1. Python SDK performance gate baseline:
   - `cd sdk/python && python -m pytest tests/test_benchmarks.py --benchmark-only -q`
2. Go FedAvg matrix benchmark:
   - `TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.9.linux-amd64 GOROOT=$TOOLROOT PATH=$TOOLROOT/bin:$PATH GOTOOLCHAIN=local go test ./test -run '^$' -bench BenchmarkAggregateParallel -benchmem -benchtime=300ms -count=10 -cpu=2`
3. Generate base-vs-current FedAvg comparison report:
   - `TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.9.linux-amd64 BASE_REF=origin/main BENCH_TIME=300ms BENCH_COUNT=10 BENCH_CPU=2 USE_BENCHSTAT=always BENCHSTAT_ALPHA=0.01 REPORT_PATH=results/metrics/fedavg_benchmark_compare.md ./scripts/benchmark_fedavg_compare.sh`
4. Generate bridge format comparison report:
   - `BENCH_TIME=200ms BENCH_COUNT=5 BENCH_CPU=2 BENCHSTAT_ALPHA=0.01 REPORT_PATH=results/metrics/bridge_compression_benchmark_compare.md ./scripts/benchmark_bridge_compression_compare.sh`

CI automation:

- Workflow: `.github/workflows/fedavg-benchmark-compare.yml`
- Artifact: `results/metrics/fedavg_benchmark_compare.md`
- Workflow: `.github/workflows/bridge-compression-benchmark.yml`
- Artifacts: `results/metrics/bridge_compression_benchmark_compare.md`, `results/metrics/bridge_compression_regression_compare.md`
- Workflow: `.github/workflows/performance-gate.yml`
- Artifact: `benchmark-results.json`

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

One-command apply helper (recommended):

- `sudo bash scripts/host_tuning.sh --persist`

Persist across reboots:

1. Add the keys above to `/etc/sysctl.conf` or `/etc/sysctl.d/99-mohawk-network.conf`
2. Apply persisted settings: `sudo sysctl --system`

Development-only override (non-production):

- `MOHAWK_HOST_PREFLIGHT_MODE=advisory make mainnet-one-click`

Release-signoff requirement:

- A strict gate report (`make go-live-gate-strict`) generated on a production-tuned host must be archived alongside advisory/development evidence when preparing release approvals.

## FIPS Deployment Posture and Evidence Capture

Runtime posture:

1. FIPS mode is required in production: `GODEBUG=fips140=on`
2. FIPS mode is required in production: `MOHAWK_FIPS_REQUIRED=true`
3. Startup gate behavior: orchestrator startup fails if FIPS is required and runtime FIPS is disabled.

Operational checks:

1. Runtime self-check:
    - `make fips-runtime-check`
2. Regression checks for crypto flows used operationally:
    - `make fips-regression`
3. Capture and archive evidence bundle:
    - `results/go-live/evidence/fips_evidence_bundle_2026-04-05.md`
    - `results/go-live/attestations/fips_evidence_bundle.json`

Exception handling:

- Any temporary exception to FIPS-required mode must include owner, expiration date, and compensating controls in incident/change records.
- Exceptions are not allowed for GA release signoff.

## XMSS Stateful Operations Guidance

### Rotation Cadence and Index-Limit Alerting

- Recommended cadence:
   1. Rotate XMSS signing seed quarterly in production or immediately after suspected key-state compromise.
- Index thresholds:
   1. Warn when index consumption exceeds 80% of approved budget for a seed.
   2. Trigger SEV-2 review at 90%.
   3. Enforce hard rollover before 100% usage.

### Secondary Tree Rollover Procedure

1. Prepare secondary XMSS seed and public key material in secure secret storage.
2. Enable dual-publish window where verifiers trust both current and next public keys.
3. Switch signing to secondary tree during a low-traffic maintenance window.
4. Validate attestation success and failure ratios stay inside SLO bounds for 30 minutes.
5. Revoke old tree trust and archive rollover evidence with timestamp and operator signoff.

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

## Alert Playbooks

### Alert: MohawkByzantineResilienceThresholdBreach

1. Confirm signal:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=min_over_time(mohawk_consensus_honest_ratio[10m])' | jq '.'`
2. Check active node-agent health and regional shard logs.
3. If ratio remains below threshold for >10m, fail over or drain unstable participants and open SEV-1.

### Alert: MohawkStragglerFailureRateHigh

1. Confirm failure ratio:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit",result="failure"}[5m]))/clamp_min(sum(rate(mohawk_accelerator_ops_total{operation="gradient_submit"}[5m])),1e-9))' | jq '.'`
2. Inspect recent node-agent disconnects and shard backpressure.
3. Mitigate by reducing batch pressure, then verify ratio returns below `0.0001`.

### Alert: MohawkNodeAgentsDown

1. Verify target status:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="node-agents"}' | jq '.'`
2. Restart affected node-agent container and validate registration.
3. Escalate to SEV-2 if fewer than 3 healthy instances persist for >5m.

### Alert: MohawkTPMAttestationFailuresPresent

1. Confirm failure increments:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=increase(mohawk_tpm_verifications_total{result="failure"}[10m])' | jq '.'`
2. Inspect TPM quote source integrity and CA material at `runtime-secrets/`.
3. If repeated failures continue, isolate failing nodes and open SEV-1.

### Alert: MohawkTPMFailureRatioHigh

1. Confirm ratio breach:
   - `curl -sfG http://localhost:9090/api/v1/query --data-urlencode 'query=(sum(rate(mohawk_tpm_verifications_total{result="failure"}[10m]))/clamp_min(sum(rate(mohawk_tpm_verifications_total[10m])),1e-9))' | jq '.'`
2. Compare against recent cert/key rotation or host TPM firmware changes.
3. Roll back recent attestation-plane changes or rotate certificates if compromise is suspected.

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
- `results/go-live/strict-host-evidence.md`
- `chaos-reports/*`
- `results/metrics/fedavg_benchmark_compare.md`
- `results/metrics/v2_dashboard_validation_report.md`
- `test/utility_coin_durability_test.go`
- `internal/token/ledger.go`
- `internal/pyapi/api.go`
- `HARDWARE_COMPATIBILITY.md`
- `EDGE_LITE_RESOURCE_PROFILE.md`
- `COMPLIANCE_MAPPING.md`

## Artifact Retention Policy

Recommended retention windows:

1. Routine forensics runs (`results/forensics/byzantine_rejections_*.md`, metrics JSON):
   - Keep workflow artifacts for at least 30 days.
2. Release-signoff evidence (`results/go-live/**`, strict host and TPM closure reports):
   - Keep for at least 1 year or per organizational compliance policy.
3. Incident-linked forensic reports:
   - Keep for the full incident record lifetime and legal hold windows.

Archival guidance:

- Upload finalized evidence bundles to immutable storage with release/incident identifiers.
- Keep checksums for archived bundles and link them from incident tickets.
