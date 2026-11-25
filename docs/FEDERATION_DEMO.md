# Two-tier federation demo

`cmd/federation-demo` exercises the project's real `internal/federation`
coordinators across two hosts. A global coordinator runs on the orchestrator
host; a regional coordinator runs on the worker host and forwards its completed
aggregates to the global tier. Synthetic child gradients are injected over the
project's federation RPC protocol.

## Build

```bash
CGO_ENABLED=0 go build -o federation-demo ./cmd/federation-demo
```

## Run

On the global host (A, `10.0.0.87`):

```bash
FED_DEMO_TIER=global-1 FED_DEMO_LEVEL=global FED_DEMO_CHILDREN=regional-1 \
FED_DEMO_MIN_QUORUM=1 FED_DEMO_LISTEN=:9125 FED_DEMO_STATS_ADDR=:9130 \
./federation-demo
```

On the regional host (B, `10.0.0.29`):

```bash
FED_DEMO_TIER=regional-1 FED_DEMO_LEVEL=regional FED_DEMO_PARENT=10.0.0.87:9125 \
FED_DEMO_CHILDREN=child-1,child-2,child-3 FED_DEMO_MIN_QUORUM=3 \
FED_DEMO_LISTEN=:9126 FED_DEMO_STATS_ADDR=:9131 ./federation-demo
```

Inject six child gradients into the regional tier:

```bash
FED_DEMO_TIER=regional-1 FED_DEMO_PARENT=127.0.0.1:9126 \
FED_DEMO_MODE=inject FED_DEMO_COUNT=6 FED_DEMO_INTERVAL_MS=500 ./federation-demo
```

Inspect both tiers:

```bash
curl -s http://10.0.0.87:9130/stats
curl -s http://10.0.0.29:9131/stats
```

`gradients_received`, `gradients_aggregated`, and `parent_latency_ms` show the
upward flow. The regional tier logs `forwarding aggregate to parent` only when
the new aggregation callback is configured; the global tier logs an aggregation
of child updates without a separate injection.

## Scope

This validates tiered aggregation and cross-host forwarding with synthetic
vectors — not trained model updates. It is independent of the libp2p gradient
path used by node-agents and the live Multi-Krum decision logging.
