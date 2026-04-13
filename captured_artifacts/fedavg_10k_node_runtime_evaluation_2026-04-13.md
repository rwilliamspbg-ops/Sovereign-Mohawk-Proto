# FedAvg 10k-Node Runtime Evaluation (2026-04-13)

## Scope

Executed the existing runtime profile test at 1500 and 10000 nodes to validate behavior and measure comparative execution cost under repeated runs.

Test target:

- `TestSwarmRuntimeProfileFromEnv`

Run shape:

- `-count 200` per scenario
- Scenarios: `1500_safe`, `1500_edge`, `10000_safe`, `10000_edge`
- Safe profile: `MOHAWK_SWARM_MALICIOUS_RATIO=0.44`, `MOHAWK_SWARM_EXPECT_FAILURE=false`
- Edge profile: `MOHAWK_SWARM_MALICIOUS_RATIO=0.56`, `MOHAWK_SWARM_EXPECT_FAILURE=true`

## Commands

- `MOHAWK_SWARM_NODE_COUNT=1500 MOHAWK_SWARM_MALICIOUS_RATIO=0.44 MOHAWK_SWARM_EXPECT_FAILURE=false ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_1500_safe_count200.jsonl`
- `MOHAWK_SWARM_NODE_COUNT=1500 MOHAWK_SWARM_MALICIOUS_RATIO=0.56 MOHAWK_SWARM_EXPECT_FAILURE=true ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_1500_edge_count200.jsonl`
- `MOHAWK_SWARM_NODE_COUNT=10000 MOHAWK_SWARM_MALICIOUS_RATIO=0.44 MOHAWK_SWARM_EXPECT_FAILURE=false ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_10000_safe_count200.jsonl`
- `MOHAWK_SWARM_NODE_COUNT=10000 MOHAWK_SWARM_MALICIOUS_RATIO=0.56 MOHAWK_SWARM_EXPECT_FAILURE=true ./scripts/go_with_toolchain.sh go test ./test -run '^TestSwarmRuntimeProfileFromEnv$' -count 200 -json > test-results/swarm-runtime/runtime_10000_edge_count200.jsonl`

Timing capture:

- Bash `time` output stored in `test-results/swarm-runtime/runtime_*_count200.time`

## Results

All four runs passed.

| Scenario | Pass/Fail | Wall Time (s) | User (s) | Sys (s) | Mean ms/iteration (200 runs) |
| --- | --- | ---: | ---: | ---: | ---: |
| 1500_safe | pass | 1.545 | 2.117 | 0.984 | 7.725 |
| 1500_edge | pass | 1.113 | 1.310 | 0.609 | 5.565 |
| 10000_safe | pass | 0.999 | 1.139 | 0.609 | 4.995 |
| 10000_edge | pass | 1.108 | 1.177 | 0.627 | 5.540 |

## Interpretation

- Functional result: the runtime profile logic accepts expected-safe and expected-edge outcomes at 10k-node configured input values.
- Cost result: per-iteration wall-time is in the 5 to 8 ms range for all scenarios and does not grow materially from 1500 to 10000.
- Important caveat: this test path is profile-validation logic over in-process aggregator math; it is not a distributed soak/load test with network, router, queueing, or long-lived straggler dynamics.

## Performance Improvement Assessment

Current code path appears computationally stable for this synthetic profile check, but this does not yet demonstrate real 10k-node runtime scaling.

High-impact next improvements:

1. Add sustained 30 to 60 minute distributed harness runs at 1500, 3000, 5000, and 10000 configured nodes with router and metrics endpoints active.
2. Record and diff `.prom` snapshots for `bridge_total`, `proof_total`, `mohawk_router_requests_total`, and FedAvg aggregation counters before and after each run.
3. Add p95/p99 round latency and straggler-fraction time series to isolate tail-latency regressions under edge profiles.
4. Introduce async or semi-async aggregation mode A/B variants in the same matrix to quantify straggler mitigation impact.
5. Extend report output with throughput versus nodes (effective gradients aggregated per second) and convergence-quality trends where applicable.

## Artifact Paths

- `test-results/swarm-runtime/runtime_1500_safe_count200.jsonl`
- `test-results/swarm-runtime/runtime_1500_edge_count200.jsonl`
- `test-results/swarm-runtime/runtime_10000_safe_count200.jsonl`
- `test-results/swarm-runtime/runtime_10000_edge_count200.jsonl`
- `test-results/swarm-runtime/runtime_1500_safe_count200.time`
- `test-results/swarm-runtime/runtime_1500_edge_count200.time`
- `test-results/swarm-runtime/runtime_10000_safe_count200.time`
- `test-results/swarm-runtime/runtime_10000_edge_count200.time`
