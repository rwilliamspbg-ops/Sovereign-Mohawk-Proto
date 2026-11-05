# Deployment Guide — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Deployment paths

Three paths (expanded from `docs/guides/GETTING_STARTED.md`):

### A. Docker Compose (single host)

```bash
docker compose up -d
# or full stack:
docker compose -f docker-compose.full.yml up -d
```

Compose files: `docker-compose.yml`, `docker-compose.full.yml`,
`docker-compose.sandbox.yml`, `docker-compose.wsl2.yml`,
`docker-compose.phase3-staging.yml`.

### B. Kubernetes (Kind + Helm)

```bash
make deploy-to-kind
# or
scripts/helm-install.sh
scripts/kind_post_deploy_health.sh
```

Helm charts: `deploy/helm/kubernetes/`. Cloud templates: `deploy/helm/cloud-templates/`.

### C. Genesis launch (node bootstrap)

```bash
./scripts/genesis-launch.sh --regional-shard local-us-east --metrics-profile global-testnet
# all nodes:
./scripts/genesis-launch.sh --all-nodes
```

## 2. Resource requirements

- Based on 500-pod test evidence in `results/go-live/evidence/`.
- Constrained hosts: set `MOHAWK_DISABLE_QUIC=true`.

## 3. Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `MOHAWK_REGIONAL_SHARD` | Regional shard name | `local-us-east` |
| `MOHAWK_METRICS_PROFILE` | Metrics profile | `global-testnet` |
| `MOHAWK_DISABLE_QUIC` | Disable QUIC transport | unset |
| `MOHAWK_ALLOW_INSECURE_WASM_FALLBACK` | Insecure verifier fallback (CI/dev only) | unset |

## 4. Post-deployment validation

Run `docs/guides/POST_DEPLOYMENT_VALIDATION.md` smoke tests and
`make go-live-gate`.

## 5. Cross-references

- Getting started: `docs/guides/GETTING_STARTED.md`
- Operations: `docs/guides/OPERATIONS.md`
- Monitoring: `docs/guides/MONITORING_OBSERVABILITY.md`
- Scaling: `docs/guides/SCALING_OPERATIONS.md`
