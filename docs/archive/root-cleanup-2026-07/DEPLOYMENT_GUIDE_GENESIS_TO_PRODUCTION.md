# Genesis-to-Production Deployment Guide

## Purpose

This guide defines the canonical rollout path from local/genesis validation to production deployment for v1.0.0.

## 1. Prerequisites

- Docker Engine + Docker Compose plugin available.
- Go toolchain aligned with `go.mod`.
- Python 3.8+ for readiness and evidence scripts.
- Runtime secrets present under `runtime-secrets/`.
- If QUIC is enabled, production host kernel tuning applied for UDP/socket buffers.

Required kernel settings (QUIC-enabled profile):

- `net.core.rmem_max=8388608`
- `net.core.rmem_default=262144`
- `net.core.wmem_max=8388608`
- `net.core.wmem_default=262144`

Constrained-host profile (default local compose path):

- Set `MOHAWK_DISABLE_QUIC=true` for orchestrator and node-agents.
- This removes QUIC listen sockets and avoids UDP buffer warnings on restricted hosts.
- Re-enable QUIC only on hosts where the kernel tuning above is enforced and validated.

## 2. Stage A: Genesis Bring-up (Local/Pre-Prod)

1. Start baseline regional profile:
   - `./genesis-launch.sh --regional-shard local-us-east`
2. Or launch full local 3-node stack:
   - `./scripts/launch_full_stack_3_nodes.sh --no-build`
3. Validate service health:
   - `curl -fsS http://localhost:9090/-/healthy`
   - `curl -fsS http://localhost:3000/api/health`

Exit criteria:

- Orchestrator, node-agents, Prometheus, Grafana, and TPM exporter are healthy.
- Baseline metrics are available.
- No verifier bypass warnings in node-agent logs (proof verifier must be active or startup fails).

## 3. Stage B: Readiness and Chaos Qualification

1. Run readiness gate:
   - `python3 scripts/mainnet_readiness_gate.py --retries 60 --delay 2 --min-bridge-transfers 1 --min-proof-verifications 1 --min-hybrid-verifications 1`
2. Run all chaos drills:
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh grafana chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh orchestrator chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh prometheus chaos-reports`
   - `RECOVERY_LATENCY_MAX_SECONDS=120 bash scripts/chaos_readiness_drill.sh tpm-metrics chaos-reports`
3. Generate readiness digest:
   - `python3 scripts/generate_readiness_digest.py --readiness-report results/readiness/readiness-report.json --chaos-dir chaos-reports --output results/readiness/readiness-digest.md`

Exit criteria:

- Readiness report `ok=true`.
- Every chaos summary has `recovery_latency_ok=true`.

## 4. Stage C: Formal Go-Live Validation

1. Advisory validation (non-production hosts):
   - `make go-live-gate-advisory`
2. Strict validation (production hosts):
   - `make go-live-gate-strict`
3. Golden path end-to-end evidence:
   - `make golden-path-e2e`

Required artifacts:

- `results/go-live/go-live-gate-report.json`
- `results/go-live/golden-path-report.json`
- `results/go-live/golden-path-report.md`
- `results/go-live/strict-host-evidence.md`

## 5. Stage D: SLO and Performance Sign-off

1. Ensure SLO baseline is current:
   - `results/go-live/evidence/slo_sli_baseline_2026-03-28.md`
2. Validate failure-injection latency evidence:
   - `python3 scripts/validate_failure_injection_latency.py`
3. Regenerate release performance evidence index:
   - `make release-performance-evidence`

Exit criteria:

- Failure-injection latency report is PASS.
- Performance evidence artifacts are present and attached to release package.

## 6. Stage E: Security and Release Candidate Sign-off

1. Verify security evidence is attached:
   - `results/go-live/evidence/security_audit_report_2026-03-26.md`
   - `results/go-live/evidence/penetration_test_report_2026-03-26.md`
   - `results/go-live/evidence/threat_model_refresh_2026-03-26.md`
   - `results/go-live/evidence/dependency_sla_baseline_2026-03-26.md`
2. Execute release checklist:
   - `RELEASE_CHECKLIST_v1.0.0_RC.md`
3. Archive RC package with checksums.

Exit criteria:

- All checklist items complete except explicitly deferred TPM items.
- RC approvers sign off.

## 7. Stage F: Production Rollout

1. Promote release image/build artifacts.
2. Roll out orchestrator and node-agents by region using staged deployment windows.
3. Monitor proof latency, bridge latency, recovery SLO, and TPM verification ratios.
4. Keep rollback package and previous release manifest available.

Rollback trigger examples:

- Sustained SLO breach (latency or recovery).
- Security-critical incident.
- Attestation integrity regression.

## 8. Post-Deployment Validation

- Re-run strict go-live gate within production environment.
- Capture 24-hour operational metrics and incident summary.
- Publish post-deploy validation note in release artifacts.

## References

- `OPERATIONS_RUNBOOK.md`
- `ROADMAP.md`
- `results/go-live/README.md`
- `results/metrics/release_performance_evidence.md`
- `RELEASE_CHECKLIST_v1.0.0_RC.md`
