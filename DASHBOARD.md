# 🏆 Contributor Standings & System Dashboard

## 🧭 Program Status

**Program Stage:** Go-Live Formalization Complete  
**Current Phase:** v1.0.0 GA Closure (Q2 2026)

**PQC Release Notes:** [RELEASE_NOTES_PQC_OVERHAUL.md](RELEASE_NOTES_PQC_OVERHAUL.md)

### Current Critical Path

* TPM attestation production-path sign-off maintenance (keep cross-platform evidence fresh)
* Release-owner approval and v1.0.0 GA tag cut

Current TPM closure evidence:

* `results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.md`
* `results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.md`
* `results/go-live/evidence/tpm_closure_summary_2026-04-11.md`
* `results/go-live/evidence/go_toolchain_alignment_2026-03-31.md`

### Formal Go-Live Gate Status

* Runtime gates: ✅ readiness / ✅ chaos / ✅ strict host preflight pass (2026-04-17)
* Attestations approved: 8/8
* TPM closure status: ✅ approved (cross-platform matrix PASS, validator PASS)
* GA tag readiness: ✅ local safety check pass (`python3 scripts/enforce_ga_tag_safety.py --tag v1.0.0`)

Current strict-go-live evidence:

* `results/go-live/evidence/go_live_gate_strict_2026-04-17.json`
* `captured_artifacts/ga_release_readiness_2026-04-17.md`

Router integration evidence with published images:

* `results/go-live/evidence/router_integration_published_images_2026-04-11.md`

Prominent scaling evidence index:

* `results/metrics/scaling_evidence_spotlight_2026-04-11.md`

### PQC Major Release

* Status: ✅ complete
* Scope: Hybrid transport KEX enforcement, XMSS attestation mode checks, migration epoch cryptographic cutover
* Evidence: `RELEASE_NOTES_PQC_OVERHAUL.md`, `results/readiness/one-click-pipeline-report.json`

Primary artifact trail:

* `results/go-live/go-live-gate-report.json`
* `results/go-live/attestations/`

## 📊 Network Health

| Metric | Status | Proof Link |
| :--- | :--- | :--- |
| **Active Nodes** | 500/500 | [Scale Test Results](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/tree/main/results) |
| **BFT Resilience** | 55.5% | [Theorem 1](https://www.kimi.com/preview/19c56c2b-c9e2-85fa-8000-0518f5fdf88c#691) |
| **Sync Latency** | 10.4ms | [Performance Gate](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions/workflows/performance-gate.yml/badge.svg) |

## 🥇 Contributor Leaderboard (Points)

| Rank | Contributor | Points | Impact Area |
| :--- | :--- | :--- | :--- |
| 1 | @rwilliamspbg-ops | 2,505 | Core Runtime & SDK |
| 2 | @Eddie-Adams | 1,000 | CI + Runtime Security Hardening |
| 3 | *Open Slot* | -- | TPM Attestation Logic |

Latest awarded contribution:

* @rwilliamspbg-ops: +5 points for documentation refresh and FedAvg scaling evidence update (commit `181e538`)

* @Eddie-Adams: +500 points for PR contribution anchored by commit `83e8ba2215db4d26edc283b6c9d7d88d92cc5c85`
* @Eddie-Adams: +500 points for Apr 2026 security patch contribution (fail-closed verifier + constrained-runtime transport mitigation), commit note recorded (merge hash pending)

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

### Operations Metric Contract (CI Enforced)

For smoke validation and release confidence, Operations dashboards rely on these metric/query families:

* `mohawk_*` metric family presence
* `mohawk_tpm_*` metric family presence

Required Prometheus jobs for baseline panel population:

* `orchestrator`
* `tpm-metrics`
* `pyapi-exporter`

CI checks:

* `.github/workflows/monitoring-smoke-gate.yml` validates Prometheus/Grafana health, required dashboard registration, target readiness, and key query family population.

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
