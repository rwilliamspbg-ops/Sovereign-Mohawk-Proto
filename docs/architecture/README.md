# System Architecture

Real content as of 2026-11-04. See `docs/ARCHITECTURE.md` for the overview and
the files in this directory for component detail:

- `BYZANTINE_RESILIENCE.md` — Multi-Krum filtering, `n > 2f+2` guard.
- `DIFFERENTIAL_PRIVACY.md` — RDP accounting, epsilon = 2.0.
- `STREAMING_AGGREGATOR.md` — chunk assembly, batching.
- `TRANSPORT_LAYER.md` — MRC multi-path spraying, PQC KEX.
- `FEDERATION_PROTOCOL.md` — tier hierarchy, gRPC forwarding.
- `GOSSIP_PROTOCOL.md` — discovery, health monitoring.
- `ROUTING_TOPOLOGY.md` — DAG routing, failover.
- `INTEGRATION_POINTS.md` — hooks (Byzantine, DP, ZK, streaming).
