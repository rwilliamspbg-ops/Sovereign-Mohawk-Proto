# Post-Deployment Validation — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Smoke tests

- Node health: `curl http://<node>:8080/health`.
- Federation health: `HealthCheckRequest` / `HealthCheckResponse`.
- Formal proofs: `make audit-ready-check`.

## 2. Validation matrix

| Check | Command / evidence |
|---|---|
| Formal proofs | `make audit-ready-check` |
| Go tests | `go test ./...` |
| Go tests (race) | `go test -race ./...` |
| Vulnerability scan | `govulncheck ./...` |
| Markdown links | `python3 scripts/ci/check_markdown_links.py` |
| Post-deploy health | `scripts/kind_post_deploy_health.sh` |
| Chaos readiness | `mainnet-chaos-gate` workflow |

## 3. Evidence

- Save validation results under `results/go-live/evidence/`.
- CI artifacts retained 7 days.

## 4. Cross-references

- Deployment: `docs/guides/DEPLOYMENT.md`
- Operations: `docs/guides/OPERATIONS.md`
- Troubleshooting: `docs/guides/TROUBLESHOOTING.md`
