# Scaling Operations — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What the 500-pod test showed

- Evidence: `results/go-live/evidence/` (distributed systems transport evidence).
- Demonstrates multi-node federation under load with Multi-Krum filtering.

## 2. Known single-host limits

- QUIC UDP-buffer instability on constrained hosts (use
  `MOHAWK_DISABLE_QUIC=true`).
- TPM attestation only hardware-backed on Linux.
- In-process MPC trusted setup is a demo key (not a distributed ceremony).

## 3. Adding node-agents safely

1. Provision TPM-backed identity (Linux) or accept default backend.
2. Set `MOHAWK_REGIONAL_SHARD` and `MOHAWK_METRICS_PROFILE`.
3. Verify `NodesPerCommittee > 2*f+2` for the chosen Byzantine bound.
4. Run `scripts/kind_post_deploy_health.sh` after scaling.

## 4. Auto-scaling

- Helm-based scaling via `deploy/helm/kubernetes/`.
- Cloud templates: `deploy/helm/cloud-templates/`.

## 5. Cross-references

- Deployment: `docs/guides/DEPLOYMENT.md`
- Operations: `docs/guides/OPERATIONS.md`
- Byzantine resilience: `docs/architecture/BYZANTINE_RESILIENCE.md`
