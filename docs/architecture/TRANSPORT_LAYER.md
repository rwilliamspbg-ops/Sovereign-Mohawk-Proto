# Transport Layer — MRC Multi-Path Spraying

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Multi-path packet spraying (MRC) with PQC hybrid KEX for transport security.

- Implementation: `internal/transport/`, `internal/crypto/`.
- KEX: x25519-mlkem768 hybrid (PQC).
- Health monitoring: `HealthCheckRequest` / `HealthCheckResponse` in the federation proto.

## 2. How it works

- Gradients are split into chunks and sprayed across multiple network paths for availability and throughput.
- Each path is authenticated (mTLS + PQC KEX).
- Receiver reassembles chunks (see `STREAMING_AGGREGATOR.md`).

## 3. Configuration / fallbacks

- `MOHAWK_DISABLE_QUIC=true`: fall back to authenticated TCP when QUIC UDP buffers cannot be tuned (constrained hosts).
- Badge: "MRC Transport Multi-Path Spraying".

## 4. Cross-references

- Federation protocol: `docs/architecture/FEDERATION_PROTOCOL.md`
- Security: `docs/security/THREAT_MODEL.md` (tampering, DoS)
- API: `docs/api/GRPC_FEDERATION.md`
