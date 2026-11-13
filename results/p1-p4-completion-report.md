# P1/P4 Completion Report

Generated: 2026-11-12

## Scope
This report covers audit-priority P1 (cryptographic/runtime verification) and
P4 (repository hygiene and claim integrity) items tracked after the 2026-11-09
deep audit, updated for the work merged through PR #321.

## Completed items (verified)

### P1 — Cryptographic verification

1. **True WASM cryptographic verification (PRs #293, #294)**
   - Rust `verify_proof` performs real ed25519 signature verification over
     `sig(64) || pubkey(32) || message`.
   - Host writes proof bytes into WASM memory via exported `alloc` and calls
     `verify_proof(ptr, len)`.
   - Empty/all-zero proofs are rejected (#293).
   - Node-agent generates real ed25519-signed proofs.
   - Verified: `go build ./internal/wasmhost/... ./cmd/node-agent/...` and
     `go test ./internal/wasmhost/... ./cmd/node-agent/...` pass.

2. **Noir circuit compiles and is sound (PR #295)**
   - `circuits/src/main.nr` compiles with Noir 1.0.0.
   - `nargo test` passes.
   - Norm bound uses 64-bit range checks and `u128` comparison.
   - `model_hash_after` and `update_hash` are bound via Pedersen hash chains.
   - CI workflow `.github/workflows/noir-circuit-check.yml` added.

3. **Federation protobuf + real gRPC runtime (PRs #296, #301)**
   - `federation.proto` compiles with `protoc`; generated Go code in
     `gen/federation` builds.
   - `internal/federation/real_grpc.go` implements a real gRPC server/client
     with a round-trip test.

4. **TEE provider abstraction, probes, and protected aggregation
   (PRs #263, #266, #297)**
   - `internal/tee` provides a hardware-agnostic `TEEProvider` interface, a
     fail-closed `TrustedMeasurements` allow-list, a simulation backend, and
     `ProtectedAggregator`.
   - SGX/SEV-SNP/TrustZone `Available()` probe `/dev` nodes.
   - `Aggregator` gains optional TEE fields plus `EnclaveAvailable` and
     `RunAggregationInEnclave` (#266).
   - Enclave creation remains fail-closed until full backends are implemented.

5. **Real Groth16 prover + client-side ZK prover interface (PRs #269, #299)**
   - `internal/zkprover` gains a gnark/BN254 `DataCommitment` prover with a
     Prove/Verify round-trip test.
   - Backend-agnostic `Prover` interface with `MockProver`, `CLIProver`, and
     `SelectProver`.

6. **Real batch signature verification (PRs #303, #304)**
   - `internal/batch/batch.go::VerifySignatures` verifies ed25519 signatures in
     parallel.
   - `FuzzVerifySignatures` fuzz target and CI gate added.

7. **MPC aggregator (PR #268)**
   - `internal/mpc` implements `SplitVector`, `Aggregate`, and a coordinator
     `(n,n)` additive secret-sharing round.

8. **Async consensus and convergence bridge (PRs #275, #276)**
   - `AsyncMode` + `StalenessWindow` in `TierConfig`; stale-gradient-tolerant
     flush.
   - `proofs/Refinement/AsyncConvergence.lean` bounds the async envelope.

9. **mDNS local discovery (PR #273)**
   - `internal/network.Discovery` gains mDNS lookup.

10. **Axiom-free, sorry-free Lean development (PRs #313, #315, #316, #318)**
    - Three dead axioms deleted (#313); the last `sorry`
      (`supermartingale_convergence_ae`) closed (#315); the eight `Float`
      order axioms packaged as the explicit `FloatOrderLaws` structure (#316);
      `dlL_prime` demoted to an explicit hypothesis (#318).
    - `#print axioms` reports only Mathlib's foundation; CI enforces no new
      `sorry`/`admit`/`axiom`.

### P4 — Hygiene and claim integrity

1. **Orphaned file removal (PRs #291, #292)**
   - Removed orphaned Rust attestation files and stray top-level artifacts;
     `pyapi.exe` ignored.

2. **Placeholder claim corrections (PR #290)**
   - Legacy attestation fallback gated behind explicit env opt-in; secure-default
     regression test added; zero-placeholder documentation claim corrected.

3. **Dependency CVE fixes (PRs #222, #289)**
   - `zlib` bumped to `>=1.4-r0` in the scanned container image.
   - `follow-redirects` bumped to 1.16.2 (CVE-2026-116689).

4. **Audit-readiness pack (PR #270)**
   - Load-bearing crypto axioms isolated as named assumptions; public claims
     aligned to `FORMAL_TRACEABILITY_MATRIX`; MPC trusted-setup caveat
     documented; `make audit-bundle` added.

5. **External audit scope (PR #252)**
   - `docs/EXTERNAL_AUDIT_SCOPE.md`, review log, and README call for review.

6. **Verified documentation content (PRs #253–#258)**
   - Security, API, architecture, ops/perf/example scaffold docs replaced with
     verified content; certificate of security/infra posture added.

7. **Fuzz and property-test expansion (PRs #303–#310)**
   - Fuzz targets for aggregation, batch verification, hbft, WASM, and
     hash-commitment verification; property tests for every `internal/`
     package.

## Remaining work (not completed)

### P1 (remaining)
- Full TEE enclave creation/attestation (probes + fail-closed stubs only).
- Real ZK prover integration (sidecar/cgo); `mock.go` and `cli.go` remain
  explicitly simulated.
- Real SNARK/STARK backends (`simulated_fri`, `winterfell_mock` in
  `internal/hybrid/verifier.go`).
- GPU/NPU real acceleration (currently detection-only).
- MPC threshold networking (multi-path transport still timer-based).
- Populate gradient/model commitments in production ZK verifier callers.
- Multi-host/WAN evidence or single-host labelling.

### P4 (remaining)
- Deeper `docs/INDEX.md` and archive cleanup (stale "Last Updated" date and
  placeholder-scaffold references).
- Cloud deployment script placeholders (`/REPLACE/...`).
- Python Vault and K8s credential providers (`NotImplementedError`).
- Threshold aggregation plaintext package scope decision (S3.5).
- Remove dummy test assertions (fuzz seed targets still contain `t.Skip()`
  paths).

## Verification commands
```bash
go build ./...
go vet ./...
go test ./internal/tee/... ./internal/wasmhost/... ./internal/batch/... ./cmd/node-agent/...
# in proofs/
lake build LeanFormalization Specification Refinement
# in circuits/
nargo compile
nargo test
```

## Conclusion
P1 and P4 have advanced materially: the Lean development is now axiom-free and
sorry-free, WASM/Noir/protobuf/gRPC are real, TEE/MPC abstractions are in place
with honest fail-closed scoping, and every `internal/` package carries at least
one machine-checked invariant. Remaining items require multi-week engineering
(TEE backends, real ZK provers, MPC networking, WAN evidence) and are tracked
as open work items rather than claimed complete.
