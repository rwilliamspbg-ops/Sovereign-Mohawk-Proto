# Edge Lite Resource Profile

This guide defines minimum resource envelopes for low-power mobile and IoT participants running node-agent workloads with WASM verification enabled.

## Goals

- Prevent resource starvation on constrained devices.
- Keep proof verification and gradient submission responsive.
- Avoid battery/thermal runaway on medical and embedded sensors.

## Suggested Profiles

| Profile | Target Device Class | vCPU | RAM | Storage | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `lite-min` | Low-power IoT gateway / sensor hub | 1 | 256 MB | 256 MB free | Use `int8` gradient format and conservative supervisor interval |
| `lite-recommended` | Mid-tier edge gateway | 2 | 512 MB | 512 MB free | Preferred for stable STARK/SNARK verification loops |
| `standard` | x86/ARM edge server | 2+ | 1 GB+ | 1 GB+ free | Full telemetry and lower round intervals |

## Runtime Flags for Lite Nodes

Use these settings on constrained nodes:

```bash
export MOHAWK_GRADIENT_FORMAT=int8
export MOHAWK_SUPERVISOR_INTERVAL_SECONDS=60
export MOHAWK_TOTAL_NODES=100000
export MOHAWK_MESH_DIMENSIONS=256
```

Rationale:

- `int8` reduces wire and memory footprint for gradients.
- Longer supervisor interval reduces sustained CPU wake-ups.
- Reduced simulated topology dimensions avoid unrealistic memory pressure during local testing.

## WASM Verification Guardrails

1. Keep one active verifier instance per process.
2. Prefer longer round intervals on battery-powered nodes.
3. Monitor p95 verification latency:

```bash
curl -sfG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(mohawk_proof_verification_latency_ms_bucket[5m])) by (le))'
```

1. If p95 exceeds local budget:

- Increase `MOHAWK_SUPERVISOR_INTERVAL_SECONDS`.
- Keep `MOHAWK_GRADIENT_FORMAT=int8`.
- Move heavy verification to gateway tier and keep sensor tier as data source + attestation only.

## Suggested Profiling Workflow

1. Start with sandbox profile:

```bash
docker compose -f docker-compose.sandbox.yml up -d --build
```

1. Capture container resource usage:

```bash
docker stats --no-stream orchestrator node-agent-1 node-agent-2
```

1. Capture latency metrics for 10 minutes and record p95 values.

1. Repeat after changing one variable at a time:

- gradient format (`fp16` vs `int8`)
- supervisor interval
- proof mode policy

## Lite Deployment Safety Checklist

- Confirm memory headroom >= 20% under peak rounds.
- Confirm no OOM kills during 30-minute soak.
- Confirm attestation success remains stable.
- Confirm proof latency is within device-class SLO.

Document final profile in deployment records before enrolling production medical or safety-critical sensors.
