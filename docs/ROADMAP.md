# Roadmap

This roadmap tracks the gap between documented claims and runtime implementation. It is updated as items are completed.

## Status legend

- ✅ Complete
- 🔄 In progress
- ⏳ Planned
- ⚠️ Blocked

## Phase 0 — Stop the bleeding (1 week)

- ✅ L1 supermartingale convergence proof completed (PR #286); the almost-sure
  strengthening `supermartingale_convergence_ae` was closed in #315. The Lean
  development is now axiom-free and sorry-free (#313, #315, #316, #318).
- ✅ Legacy empty-proof attestation fallback disabled by default
  (`MOHAWK_ALLOW_LEGACY_ATTESTATION=1` to opt in).
- ✅ Added secure-default regression test
  (`TestProcessRound_RequiresGradientCommitmentByDefault`).
- ✅ Clarified `TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md` zero-placeholder
  claim (L1 only).
- ✅ `internal/thresholdagg` documented as plaintext, not FHE.
- ⏳ Correct stale scaffold references in `docs/INDEX.md` (still marked
  "Last Updated: May 9, 2026" and references placeholder scaffolds).

## Phase 1 — Real cryptography and verification (2–4 weeks)

- ✅ Wire Noir toolchain: `circuits/src/main.nr` compiles with Noir 1.0.0,
  `nargo test` passes, CI workflow added (PR #295).
- ✅ Real WASM `verify_proof`: Rust ed25519 verification over
  `sig(64) || pubkey(32) || message`; the host passes proof bytes via the
  exported `alloc` (PR #294). Empty/all-zero proofs are rejected (#293).
- ✅ Node-agent zero-byte proofs/zero gradients replaced with real
  ed25519-signed proofs (PR #294).
- ✅ Real batch signature verification:
  `internal/batch/batch.go::VerifySignatures` verifies ed25519 signatures in
  parallel; fuzz gate added in #304.
- ⏳ Replace simulated STARK backends (`simulated_fri`, `winterfell_mock` in
  `internal/hybrid/verifier.go`) with real implementations or remove claims.
- 🔄 Populate gradient/model commitments in production ZK verifier callers:
  `Aggregator.GradientCommitment` is verified when non-nil, but production
  callers must supply it; not yet wired end-to-end.

## Phase 2 — Hardware, transport, and scale honesty (3–6 weeks)

- 🔄 Real TEE providers: SGX/SEV-SNP/TrustZone `Available()` probe `/dev`
  nodes (PR #297); enclave creation remains fail-closed until full backends
  are implemented. TEE provider abstraction and protected aggregation hooks
  landed in #263/#266.
- ⏳ Implement real GPU/NPU kernels or remove acceleration claims (currently
  detection-only).
- ⏳ Implement real multi-path transport or rename as simulated (MRC adapter
  is timer-based).
- ✅ Generate protobuf bindings (PR #296) and wire the runtime to a real gRPC
  service (PR #301).
- 🔄 Real MPC threshold sharing: `internal/mpc` implements an in-process
  additive secret-sharing round (PR #268); distributed threshold networking is
  not implemented.
- ⏳ Add multi-host/WAN evidence or label single-host results.

## Phase 3 — SDK and cloud completeness (2–3 weeks)

- ⏳ Implement Vault/K8s credential providers or remove from SDK
  (`sdk/python/mohawk/credentials.py` still raises `NotImplementedError`).
- ⏳ Replace cloud template placeholders with real scripts or mark as samples
  (`deploy/kubernetes/scale-test/kind-config.yaml` uses `/REPLACE/...`,
  auto-substituted by `scripts/run_kind_scale_*.sh`).
- ⏳ Remove dummy test assertions (fuzz seed targets still contain `t.Skip()`
  paths).

## Phase 4 — Codebase hygiene (1 week)

- ✅ Remove orphaned Rust files (PRs #291, #292).
- ✅ Remove duplicate `server/` directory (no `server/` remains).
- ✅ Remove `pyapi.exe` and update `.gitignore` (PR #291).
- ✅ Delete 0-byte abandoned files (none tracked).
- ⏳ Correct `docs/INDEX.md` (stale "Last Updated" date and placeholder-scaffold
  references).

## Recent security work

- ✅ PR #289: upgraded `zlib` to `>=1.4-r0` in the scanned container image
  (CVE-2026-4738).
- ✅ PR #222: `follow-redirects` bumped to 1.16.2 (CVE-2026-116689).
