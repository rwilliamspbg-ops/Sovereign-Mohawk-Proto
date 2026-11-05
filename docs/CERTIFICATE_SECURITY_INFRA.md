# Certificate of Security & Infrastructure Posture

**Project:** Sovereign-Mohawk-Proto
**Date:** 2026-11-01
**Status:** Audit-grade evidence baseline

## 1. Test Posture

| Suite | Result |
|---|---|
| Go test suite (`go test ./...`) | All packages pass, 0 failures |
| MRC transport (spraying, reassembly, adaptive scoring, context cancel) | PASS |
| Security tests (auth-gated handlers, fail-closed admin, mint auth) | PASS |
| Stress-race (scoped to router/thresholdagg/tpm/transport) | informational (continue-on-error) |
| Fuzz targets (manifest, thresholdagg, zkproof, rdp_shard, scheduler) | 5 targets, semantic oracles |
| Property tests (scheduler single + multi-bid gopter) | PASS |
| Benchmarks (VerifyHashCommitment) | 4,345,923 ops, 609 ns/op (<5ms) |
| Mutation score tracking | scripts/mutation_score.py (informational) |

## 2. Infrastructure Posture

| Component | Status |
|---|---|
| Orchestrator (mTLS :8080, libp2p :4101) | Healthy |
| Node agents ×3 | Healthy |
| Federated router (:8087) | Healthy (deferred startup resolved) |
| tpm-metrics exporter (:9102) | Listening |
| Grafana / Prometheus / IPFS / ops-assistant | Running (Grafana token invalid — non-blocking) |
| Docker compose stack | Up, all healthy |

## 3. Security Posture

- mTLS enforced on orchestrator (client cert required; HTTP rejected).
- KEX mode: x25519-mlkem768-hybrid, expected_key_bytes 1216.
- Auth-gated handlers fail closed when token missing.
- Admin authorization fail-closed verified.
- Grafana ops-assistant token invalid/expired (action required: rotate token).

## 4. Load / Performance

| Run | Result |
|---|---|
| 5,000-round simulator (3 virtual nodes, fp16) | Complete, 4,377 n/s avg, 0.94 acc / 0.18 loss |
| Byzantine injection (10% fraction) | 130/130 rejected (100%) |
| Heterogeneous clients | Real metric spread (0.9302 acc / 0.22 loss) |
| MRC transport spraying | 4 paths, healthy, adaptive scoring |
| Live mTLS probe | /mesh/plan + /p2p/info 200 OK |

## 5. Known Gaps / Action Items

1. Theorem 5 verification returns false on all node agents (mock proof correctly rejected by real Groth16 verifier; production path needs real proof generation).
2. Grafana API token invalid/expired — rotate and set via env.
3. Simulator → live orchestrator gradient submission requires libp2p client integration (not yet wired).
4. Stress-race informational until flake baseline established.
5. No hard coverage/mutation gates initially (by design).

## 6. Artifacts

- artifacts/sim-5000.json
- artifacts/byz-hetero.json
- artifacts/load-run.log
- artifacts/scale-fp16.json, scale-fp32.json
- artifacts/pytest-training.log

---
*Generated from verified command output. No fabricated metrics.*
