# Loaded 1500-Node Runtime And Sustained Stress Capture (2026-04-13)

## Objective

Follow-up evidence run to address the previously annotated scale gap with:

- 1500-node runtime profile execution (safe and edge profiles).
- Sustained router load generation with Prometheus-format metrics capture.
- Artifact publication under captured_artifacts for audit traceability.

## Commands Executed

- `source scripts/ensure_go_toolchain.sh && go clean -cache`
- `MOHAWK_SWARM_NODE_COUNT=1500 MOHAWK_SWARM_MALICIOUS_RATIO=0.44 MOHAWK_SWARM_EXPECT_FAILURE=false go test -json ./test -run '^TestSwarmRuntimeProfileFromEnv$'`
- `MOHAWK_SWARM_NODE_COUNT=1500 MOHAWK_SWARM_MALICIOUS_RATIO=0.56 MOHAWK_SWARM_EXPECT_FAILURE=true go test -json ./test -run '^TestSwarmRuntimeProfileFromEnv$'`
- `python3 scripts/publish_swarm_runtime_benchmarks.py`
- `for i in $(seq 1 40); do ROUTER_URL=http://127.0.0.1:8087 bash scripts/router_smoke_discovery.sh; done`
- `curl -fsS http://127.0.0.1:8088/metrics > ...pre_stress.prom`
- `curl -fsS http://127.0.0.1:8088/metrics > ...post_stress.prom`

## 1500-Node Runtime Matrix Result

Source artifact: `captured_artifacts/scaled_swarm_benchmark_report_1500_2026-04-13.md`

| Nodes | Profile | Result | Elapsed (s) |
| ---: | --- | --- | ---: |
| 1500 | safe | pass | 0.000 |
| 1500 | edge | pass | 0.000 |

Interpretation:

- Both matrix expectations executed successfully at 1500-node profile settings.
- Elapsed values remain near-zero because this path is profile-validation logic, not a long-running distributed soak test.

## Sustained Stress Metrics (40 router-smoke cycles)

Prometheus-format snapshots:

- `captured_artifacts/router_metrics_pre_stress_2026-04-13.prom`
- `captured_artifacts/router_metrics_post_stress_2026-04-13.prom`

Observed deltas (post - pre):

| Metric | Pre | Post | Delta |
| --- | ---: | ---: | ---: |
| `mohawk_router_requests_total{endpoint="publish",result="success"}` | 2 | 42 | +40 |
| `mohawk_router_requests_total{endpoint="subscribe",result="success"}` | 2 | 42 | +40 |
| `mohawk_router_requests_total{endpoint="discover",result="success"}` | 2 | 42 | +40 |
| `mohawk_router_requests_total{endpoint="provenance_post",result="success"}` | 2 | 42 | +40 |
| `process_cpu_seconds_total` | 0.01 | 0.10 | +0.09 |
| `process_resident_memory_bytes` | 13,639,680 | 16,523,264 | +2,883,584 |
| `go_goroutines` | 7 | 7 | 0 |

## Prometheus Availability

- Direct Prometheus endpoint (`http://127.0.0.1:9090/-/healthy`) was unavailable in this local run.
- This capture therefore uses Prometheus exposition snapshots from router metrics endpoint (`:8088/metrics`).
- For full platform-level PromQL/TSDB capture, rerun this procedure with full compose stack Prometheus enabled.

## Trend Artifact

Bridge speedup trend table produced at:

- `captured_artifacts/bridge_compression_speedup_trend_2026-04-13.md`

This table tracks commit-to-commit movement in dim512/dim2048/dim8192/dim16384 speedup factors to explain observed variance bands.
