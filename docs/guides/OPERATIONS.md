# Operations Guide — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Day-2 runbook

### Health checks

- Node agent: `curl http://localhost:8080/health` (or the configured port).
- Federation tiers: `HealthCheckRequest` / `HealthCheckResponse` (see
  `docs/api/GRPC_FEDERATION.md`).
- CI gate: `make go-live-gate` (runs the full validation).

### Common operations

| Task | Command / script |
|---|---|
| Bootstrap a node | `scripts/genesis-launch.sh` |
| Deploy to Kind | `make deploy-to-kind` |
| Helm install | `scripts/helm-install.sh` |
| Post-deploy health | `scripts/kind_post_deploy_health.sh` |
| Full stack (3 nodes) | `scripts/launch_full_stack_3_nodes.sh` |
| Sandbox | `scripts/launch_sandbox.sh` |

### Certificate rotation

- Regenerate via `scripts/genesis-launch.sh` (regenerates identity).
- Verify with cosign/SLSA (see `docs/AUDITOR_QUICK_REFERENCE.md`).

### TPM re-attestation

- `scripts/genesis-launch.sh` regenerates TPM-backed identity.
- Hardware TPM only on Linux (`internal/tpm/hardware_backend_linux_has_tpm.go`).

## 2. SLO / SLI reference

- Baselines: `results/go-live/evidence/` (latency, SLO baselines).
- Key metrics: proof verification latency, aggregation latency, attestation
  success rate, straggler timeout rate.
- Dashboards: `monitoring/grafana/`.

## 3. Backup / restore

- Utility coin ledger: backup/restore supported (see `sdk/python/README.md`).
- No persistent training state beyond model checkpoints (operator-managed).

## 4. Alerting

- Prometheus alerting rules: `monitoring/prometheus/`, `monitoring/alertmanager/`.
- See `docs/guides/MONITORING_OBSERVABILITY.md`.

## 5. Cross-references

- Deployment: `docs/guides/DEPLOYMENT.md`
- Monitoring: `docs/guides/MONITORING_OBSERVABILITY.md`
- Troubleshooting: `docs/guides/TROUBLESHOOTING.md`
- Scaling: `docs/guides/SCALING_OPERATIONS.md`
- Post-deployment validation: `docs/guides/POST_DEPLOYMENT_VALIDATION.md`
