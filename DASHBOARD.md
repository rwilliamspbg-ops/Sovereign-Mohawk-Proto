# 🏆 Contributor Standings & System Dashboard

## 📊 Network Health

| Metric | Status | Proof Link |
| :--- | :--- | :--- |
| **Active Nodes** | 500/500 | [Scale Test Results](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/main/results) |
| **BFT Resilience** | 55.5% | [Theorem 1](https://www.kimi.com/preview/19c56c2b-c9e2-85fa-8000-0518f5fdf88c#691) |
| **Sync Latency** | 10.4ms | [Performance Gate](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml/badge.svg) |

## 🥇 Contributor Leaderboard (Points)

| Rank | Contributor | Points | Impact Area |
| :--- | :--- | :--- | :--- |
| 1 | @rwilliamspbg-ops | 2,500 | Core Runtime & SDK |
| 2 | *Open Slot* | -- | ZK-SNARK Integration |
| 3 | *Open Slot* | -- | TPM Attestation Logic |

## 🛠️ Open Bounty Tasks

* **[Medium]** Implement TPM-gated key rotation (+500 pts)
* **[Easy]** Re-enable `errcheck` linter rules (+200 pts)
* **[Hard]** 1M Node Stress Test Script (+1200 pts)

---

## 📡 Operational Monitoring (Genesis Testnet)

### Service Endpoints

| Service | URL | Purpose |
| :--- | :--- | :--- |
| Grafana | `http://localhost:3000` | Dashboard UI |
| Prometheus | `http://localhost:9090` | Metrics query + scrape state |
| TPM Exporter | `http://localhost:9102/metrics` | TPM attestation metrics |
| Orchestrator | `https://localhost:8080` | Control plane / API |
| Orchestrator Metrics (internal) | `http://orchestrator:9091/metrics` | Prometheus scrape target inside Docker network |

### Health Checks

```bash
curl -fsS http://localhost:3000/api/health
curl -fsS http://localhost:9090/-/healthy
curl -fsS http://localhost:9102/metrics | head
curl -fsS http://localhost:9090/api/v1/targets | grep '"instance":"orchestrator:9091"'
```

### Provisioned Grafana Dashboards

* `MOHAWK Tokenomics` (`mohawk-tokenomics-v1`)
* `MOHAWK Live Overview`
* `MOHAWK Live Rounds`
* `MOHAWK NOC Wallboard`
* `Consensus Trust Monitoring`
* `TPM Metrics`

### Weekly Digest Webhooks (Optional)

`Weekly Readiness Digest` can send markdown summary notifications to chat systems.

Configure repository secrets in GitHub Actions:

* `SLACK_WEBHOOK_URL`
* `TEAMS_WEBHOOK_URL`

If unset, the workflow still completes normally and publishes digest artifacts.

### CI Stabilization Notes

Recent reliability hardening in CI:

* `Integrity Guard - Linter` uses Go `1.25.x` to match `go.mod` toolchain requirements.
* `Mainnet Readiness Gate` now retries target-health and metric-name checks to absorb Prometheus cold-start scrape convergence.

If readiness fails unexpectedly, first inspect scrape target state:

```bash
curl -fsS http://localhost:9090/api/v1/targets | grep -E '"instance":"orchestrator:9091"|"instance":"tpm-metrics:9102"|"health":"(up|down)"'
```
