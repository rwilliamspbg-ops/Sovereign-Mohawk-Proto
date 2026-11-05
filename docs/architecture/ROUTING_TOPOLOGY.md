# Routing and Topology

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

DAG-based tier topology with failover.

- Tier levels: Regional -> Continental -> Global (`internal/federation/types.go`).
- Path tracking: `PathHops` breadcrumb trail on `GradientMessage`.
- Routing decisions in `internal/federation/rpc_handler.go` and `coordinator.go`.

## 2. Topology properties

- Gradients carry a `path_hops` breadcrumb trail for traceability.
- Failover: when a tier link is unhealthy (`FederationHealth`), traffic reroutes via alternate paths (transport layer MRC spraying).

## 3. Open items

- Explicit DAG consistency proofs are not present; topology correctness is validated by integration tests (`federation_end_to_end_test.go`).

## 4. Cross-references

- Federation protocol: `docs/architecture/FEDERATION_PROTOCOL.md`
- Transport: `docs/architecture/TRANSPORT_LAYER.md`
- Byzantine resilience: `docs/architecture/BYZANTINE_RESILIENCE.md`
