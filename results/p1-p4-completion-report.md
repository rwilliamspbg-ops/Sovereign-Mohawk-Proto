# P1/P4 Completion Report

Generated: 2026-11-09

## Scope
This report covers audit-priority P1 (cryptographic/runtime verification) and
P4 (repository hygiene and claim integrity) items tracked after the 2026-11-09
deep audit.

## Completed items (verified)

### P1 — Cryptographic verification

1. **True WASM cryptographic verification (PR #294)**
   - Rust `verify_proof` performs real ed25519 signature verification over
     `sig(64) || pubkey(32) || message`.
   - Host writes proof bytes into WASM memory via exported `alloc` and calls
     `verify_proof(ptr, len)`.
   - Node-agent generates real ed25519-signed proofs.
   - Fallback module uses the real verifying artifact.
   - Verified: `go build ./internal/wasmhost/... ./cmd/node-agent/...` and
     `go test ./internal/wasmhost/... ./cmd/node-agent/...` pass.

2. **Noir circuit compiles and is sound (PR #295)**
   - `circuits/src/main.nr` compiles with Noir 1.0.0.
   - `nargo test` passes.
   - Norm bound uses 64-bit range checks and u128 comparison.
   - `model_hash_after` and `update_hash` are bound via Pedersen hash chains.
   - CI workflow `.github/workflows/noir-circuit-check.yml` added.

3. **Federation protobuf generated (PR #296)**
   - `federation.proto` compiles with protoc.
   - Generated Go code in `gen/federation` builds (`go build ./gen/...`).

4. **TEE availability probes (PR #297)**
   - SGX/SEV-SNP/TrustZone `Available()` now probe `/dev` nodes instead of
     always returning false.
   - Enclave creation remains fail-closed until full backends are implemented.
   - Verified: `go test ./internal/tee/...` passes.

### P4 — Hygiene and claim integrity

1. **Orphaned file removal (PRs #291, #292)**
   - Removed orphaned Rust attestation files and stray top-level artifacts.

2. **Placeholder claim corrections (PR #290)**
   - Legacy attestation fallback gated behind explicit env opt-in.
   - Roadmap honesty updates.

3. **Dependency CVE fix (PR #289)**
   - zlib bumped to Alpine release; CI passes.

4. **Formal proof convergence (PR #286)**
   - L1 supermartingale convergence proof merged; CI passed.

## Remaining work (not completed)

### P1 (remaining)
- Full TEE enclave creation/attestation and protected aggregation.
- Real ZK prover integration (sidecar/cgo) and real SNARK/STARK backends;
  `mock.go` and `cli.go` remain explicitly simulated.
- GPU/NPU real acceleration (currently detection-only).
- MPC threshold networking (multi-path transport still timer-based).
- Protobuf runtime wiring (generated code exists; federation still uses raw TCP).
- Lean proofs: `SupermartingaleConvergence.lean` sorry and 13 axioms remain.

### P4 (remaining)
- Deeper `docs/INDEX.md` and archive cleanup.
- Cloud deployment script placeholders (`/REPLACE/...`).
- Python Vault and K8s credential providers (`NotImplementedError`).
- Threshold aggregation plaintext package scope decision (S3.5).

## Verification commands
```bash
go build ./...
go vet ./...
go test ./internal/tee/... ./internal/wasmhost/... ./cmd/node-agent/...
# in circuits/
nargo compile
nargo test
```

## Conclusion
P1 and P4 have advanced materially on cryptographic verification (WASM, Noir,
protobuf) and hygiene (orphan removal, claim correction). Remaining items
require multi-week engineering (TEE backends, real ZK provers, MPC, WAN) and
are tracked as open work items rather than claimed complete.
