# Distributed 10k Runtime Evaluation (2026-04-13)

## Scope

Captured a live distributed runtime pass with the router service, bridge traffic, async aggregation controls, and the 10k swarm profile harness active in the same session.

## Commands

- `./scripts/launch_full_stack_3_nodes.sh`
- `ROUTER_URL=http://127.0.0.1:8087 ./scripts/router_smoke_discovery.sh`
- `curl -fsS http://127.0.0.1:8088/metrics | head -n 120 > test-results/swarm-runtime/router_metrics_snapshot.prom`
- `python3 scripts/strict_auth_smoke.py --token-file runtime-secrets/mohawk_api_token`
- `./scripts/go_with_toolchain.sh go test ./internal/pyapi -run '^TestAggregateUpdatesCore_AdvancedAsyncOptions$'`
- `env MOHAWK_SWARM_NODE_COUNT=10000 MOHAWK_SWARM_MALICIOUS_RATIO=0.44 MOHAWK_SWARM_EXPECT_FAILURE=false ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_10000_safe_count200.jsonl`
- `env MOHAWK_SWARM_NODE_COUNT=10000 MOHAWK_SWARM_MALICIOUS_RATIO=0.56 MOHAWK_SWARM_EXPECT_FAILURE=true ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_10000_edge_count200.jsonl`

## Results

- Router smoke: PASS.
- Router metrics snapshot: present.
- Async aggregation controls: `TestAggregateUpdatesCore_AdvancedAsyncOptions` passed.
- Bridge transfer smoke: bridge transfer succeeded in the live runtime.
- 10k safe profile: wall `1.171s`, user `1.177s`, sys `0.690s`.
- 10k edge profile: wall `1.099s`, user `1.231s`, sys `0.613s`.

## Prometheus Snapshot

Fresh metrics were captured from the router metrics endpoint at `:8088/metrics`. The snapshot includes the router request and provenance counters, including:

- `mohawk_router_requests_total{endpoint="publish",result="success",reason="none"} 243`
- `mohawk_router_requests_total{endpoint="subscribe",result="success",reason="none"} 243`
- `mohawk_router_requests_total{endpoint="discover",result="success",reason="none"} 243`
- `mohawk_router_requests_total{endpoint="provenance_post",result="success",reason="none"} 243`
- `mohawk_router_requests_total{endpoint="provenance_get",result="success",reason="none"} 243`
- `mohawk_router_provenance_records 243`

## Notes

- The published swarm report was regenerated after removing stale `count20` artifacts, so the current matrix summary reflects the fresh router-enabled capture.
- The bridge/auth smoke confirmed bridge traffic, but its negative role-block checks are not enforced in the current runtime defaults, so the bridge transfer success is the relevant signal here.

## Extended Soak (1000 Iterations)

Additional distributed soak traffic was executed against the live router while bridge and async services remained active.

- Iterations: `1000`
- Requests total: `5000`
- Elapsed: `5.051s`
- Average requests/sec: `989.85`
- Mean latency (all requests): `0.975ms`
- p95 latency (all requests): `2.425ms`

| Endpoint | Count | Mean (ms) | p95 (ms) |
| --- | ---: | ---: | ---: |
| publish | 1000 | 0.515 | 0.561 |
| subscribe | 1000 | 0.405 | 0.496 |
| discover | 1000 | 1.860 | 3.115 |
| provenance_post | 1000 | 0.491 | 0.917 |
| provenance_get | 1000 | 1.603 | 2.646 |

## Full FedAvg Round at 10k (Byzantine Mix)

Executed one explicit 10k round with Byzantine noise settings:

- `MOHAWK_SWARM_NODE_COUNT=10000`
- `MOHAWK_SWARM_MALICIOUS_RATIO=0.44`
- `MOHAWK_FEDAVG_LOCAL_EPOCHS=3`
- `MOHAWK_FEDAVG_PARTICIPATION=1.0`
- `MOHAWK_FEDAVG_ROUND_LABEL=dist10k_bz`

Command and output evidence: `test-results/swarm-runtime/fedavg_10k_byzantine_round.txt`

Result:

- `go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count=1 -timeout 20m` => `ok`

## Trend Table (In-Process vs Distributed)

Recent 10k wall-time trend from committed runtime timing artifacts:

| Date | Commit | Mode | Safe wall (s) | Edge wall (s) | Note |
| --- | --- | --- | ---: | ---: | --- |
| 2026-04-13 | 7bbb46c | distributed/router-on | 1.171 | 1.099 | test(scale): refresh distributed 10k router+bridge artifacts |
| 2026-04-13 | 9265b0e | in-process/router-off | 0.975 | 1.017 | docs(perf): refresh scaling evidence artifacts |
| 2026-04-13 | e7fc6dd | in-process/router-off | 0.999 | 1.108 | test(scale): add 10k runtime evaluation and verify CI workflow pins |

## Prometheus Deep-Dive (Pre/Post FedAvg Snapshot)

Pre/post snapshots:

- `captured_artifacts/router_metrics_pre_extended_10k_fedavg_2026-04-13.prom`
- `captured_artifacts/router_metrics_post_extended_10k_fedavg_2026-04-13.prom`

Observed deltas:

| Metric | Pre | Post | Delta |
| --- | ---: | ---: | ---: |
| `go_memstats_heap_alloc_bytes` | 4214664 | 2734920 | -1479744 |
| `process_resident_memory_bytes` | 17833984 | 16859136 | -974848 |

Findings:

- No router/FedAvg bridge counter deltas were exposed in this short pre/post window.
- No `_bucket` histogram metric families were exported by the sampled metrics endpoint, so histogram-based p95 derivation is not available from router Prometheus snapshots in the current configuration.

Detailed analysis artifact: `captured_artifacts/router_metrics_extended_10k_fedavg_analysis_2026-04-13.md`