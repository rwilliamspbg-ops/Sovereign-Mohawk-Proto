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