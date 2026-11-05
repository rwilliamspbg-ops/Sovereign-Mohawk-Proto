# Federation Protocol

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Multi-tier gradient aggregation protocol over gRPC.

- Types: `internal/federation/types.go` (`TierLevel`, `GradientMessage`, `FederationHealth`).
- RPC backend: `internal/federation/grpc_backend.go`, `rpc_client.go`, `rpc_handler.go`.
- Coordinator: `internal/federation/coordinator.go`.
- Protocol definition: `api/federation/federation.proto`.

## 2. Tiers

`TierLevel`: Regional (1) -> Continental (2) -> Global (3). (Edge nodes sit below Regional.)

## 3. Gradient forwarding

- `ForwardGradient` (unary): single gradient to parent tier.
- `ForwardBatch` (unary): bulk forward.
- `ReceiveGradients` (bidirectional stream): streaming aggregation with acks.

See `docs/api/GRPC_FEDERATION.md` for message fields.

## 4. Byzantine guard in the federation path

`internal/federation/rpc_handler.go` enforces `n > 2*f+2` for Multi-Krum; falls back to simple mean when too few updates.

## 5. Cross-references

- API: `docs/api/GRPC_FEDERATION.md`, `docs/api/API_REFERENCE.md`
- Byzantine resilience: `docs/architecture/BYZANTINE_RESILIENCE.md`
- Transport: `docs/architecture/TRANSPORT_LAYER.md`
