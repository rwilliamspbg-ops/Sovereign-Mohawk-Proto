# Integration Points

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Hook architecture

Integration hooks connect the federation/aggregation path to Byzantine filtering, DP accounting, and ZK verification.

| Hook | Location | Purpose |
|---|---|---|
| Byzantine filtering | `internal/federation/rpc_handler.go` | Multi-Krum on incoming gradients |
| DP accounting | `internal/federation/dp_tier_tracking.go` | Per-tier RDP budget tracking |
| ZK attestation | `internal/batch/aggregator.go` | Routes to `VerifyDataCommitmentProof` when `GradientCommitment` is set |
| Streaming assembly | `internal/streaming_aggregator.go` | Chunk reassembly before aggregation |

## 2. How to add a new integration point

1. Add the hook in `internal/federation/` or `internal/batch/`.
2. Add a test in the corresponding `_test.go`.
3. Update `proofs/FORMAL_TRACEABILITY_MATRIX.md` if a formal claim is affected.
4. Update this document.

## 3. Cross-references

- Byzantine resilience: `docs/architecture/BYZANTINE_RESILIENCE.md`
- Differential privacy: `docs/architecture/DIFFERENTIAL_PRIVACY.md`
- Streaming aggregator: `docs/architecture/STREAMING_AGGREGATOR.md`
- API: `docs/api/API_REFERENCE.md`
