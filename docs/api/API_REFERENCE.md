# API Reference — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Overview

Sovereign Mohawk exposes three integration surfaces:

1. **gRPC federation protocol** (`api/federation/federation.proto`) —
   gradient forwarding and aggregation across tiers.
2. **Python SDK** (`sdk/python/`) — Pythonic wrapper over the Go runtime.
3. **Go packages** (`internal/`) — direct integration for Go consumers.

There is no public REST API for the data plane; monitoring/control endpoints
are documented under `docs/guides/MONITORING_OBSERVABILITY.md` (in progress).

## 2. gRPC federation service

Service: `federation.FederationService`. Full message definitions in
`docs/api/GRPC_FEDERATION.md`.

| RPC | Type | Purpose |
|---|---|---|
| `ForwardGradient` | unary | Send a single gradient to parent tier |
| `ForwardBatch` | unary | Send multiple gradients in bulk |
| `ReceiveGradients` | bidirectional stream | Streaming gradient aggregation with acks |

## 3. Go package surface (integrator-facing)

| Package | Purpose | Key types |
|---|---|---|
| `internal/federation/` | Tier hierarchy, gradient forwarding, aggregation | `FederationNode`, RPC handlers |
| `internal/batch/` | Batch aggregation, ZK attestation routing | `Aggregator`, `GradientCommitment` |
| `internal/transport/` | Multi-path packet spraying (MRC) | transport client/server |
| `internal/crypto/` | PQC hybrid KEX (x25519-mlkem768) | KEX helpers |
| `internal/tpm/` | TPM-backed identity, attestation | `verify.go`, lease lifecycle |
| `internal/rdp_accountant.go` | RDP privacy budget | accountant |
| `internal/zksnark_circuit_verifier.go` | Circuit-derived ZK verification | `VerifyDataCommitmentProof` |
| `internal/pyapi/` | CGo exports for Python bridge | `api.go` |

For godoc-style detail, run `go doc ./internal/<package>`.

## 4. Authentication and transport

- mTLS between tiers; TPM-backed node identity.
- PQC hybrid KEX for transport (x25519-mlkem768).
- Insecure fallback (`MOHAWK_ALLOW_INSECURE_WASM_FALLBACK`) is CI/dev only.

## 5. Error model

- gRPC status codes follow standard conventions; aggregation responses carry
  `success`, `message`, `accepted_count`, `server_process_time_ms`.
- Streaming responses carry `received`, `aggregation_status`
  ("received"/"processing"/"aggregated"), and optional `round_result`.

## 6. Versioning and compatibility

- Proto package: `federation`, Go package
  `github.com/sovereign-mohawk/proto-gen/federation;federationpb`.
- Changes to the proto must be backward-compatible; field numbers are stable.
- Python SDK version: see `sdk/python/` (2.0.1.Alpha).

## 7. Cross-references

- gRPC service details: `docs/api/GRPC_FEDERATION.md`
- Python SDK guide: `docs/api/PYTHON_SDK_GUIDE.md`
- Python SDK source: `sdk/python/README.md`
- Getting started: `docs/guides/GETTING_STARTED.md`
