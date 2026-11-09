# Roadmap

This roadmap tracks the gap between documented claims and runtime implementation. It is updated as items are completed.

## Status legend

- ✅ Complete
- 🔄 In progress
- ⏳ Planned
- ⚠️ Blocked

## Phase 0 — Stop the bleeding (1 week)

- ✅ L1 supermartingale convergence proof completed (PR #286); ae strengthening remains WIP.
- ✅ Legacy empty-proof attestation fallback disabled by default (`MOHAWK_ALLOW_LEGACY_ATTESTATION=1` to opt in).
- ✅ Added secure-default regression test (`TestProcessRound_RequiresGradientCommitmentByDefault`).
- ✅ Clarified `TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md` zero-placeholder claim (L1 only).
- ✅ `internal/thresholdagg` already documented as plaintext, not FHE.
- ⏳ Correct stale scaffold references in `docs/INDEX.md`.

## Phase 1 — Real cryptography and verification (2–4 weeks)

- ⏳ Wire Noir toolchain or replace skeleton in `circuits/weight_update.nr`.
- ⏳ Replace simulated STARK backends (`simulated_fri`, `winterfell_mock`) with real implementations or remove claims.
- ⏳ Implement real batch signature verification in `internal/crypto/batch.go`.
- ⏳ Populate gradient/model commitments in production ZK verifier callers.
- ⏳ Implement real WASM `verify_proof`; replace 46-byte stub and hardcoded gradients.
- ⏳ Replace node-agent zero-byte proofs/zero gradients with real inputs.

## Phase 2 — Hardware, transport, and scale honesty (3–6 weeks)

- ⏳ Implement real TEE providers or remove/market as simulated.
- ⏳ Implement real GPU/NPU kernels or remove acceleration claims.
- ⏳ Implement real multi-path transport or rename as simulated.
- ⏳ Generate protobuf bindings or standardize on TCP framing.
- ⏳ Implement real MPC threshold sharing or mark as in-process simulation.
- ⏳ Add multi-host/WAN evidence or label single-host results.

## Phase 3 — SDK and cloud completeness (2–3 weeks)

- ⏳ Implement Vault/K8s credential providers or remove from SDK.
- ⏳ Replace cloud template placeholders with real scripts or mark as samples.
- ⏳ Remove dummy test assertions.

## Phase 4 — Codebase hygiene (1 week)

- ⏳ Remove orphaned Rust files (`src/attestation.rs`, `node/src/attestation.rs`).
- ⏳ Remove duplicate `server/` directory.
- ⏳ Remove `pyapi.exe` and update `.gitignore`.
- ⏳ Delete 0-byte abandoned files.
- ⏳ Correct `docs/INDEX.md`.

## Recent security work

- ✅ PR #289: upgraded `zlib` to `>=1.4-r0` in the scanned container image (CVE-2026-4738).
