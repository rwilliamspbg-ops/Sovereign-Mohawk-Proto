# PQC Sprint Build (Local Only)

Branch: `feature/pqc-hybrid-sprint-build`

## Scope

This sprint bootstraps implementation for the 2026–2027 PQC migration plan using safe, incremental hooks:

- Phase A (Q3 2026): libp2p transport KEX mode hooks for X25519 and Hybrid X25519+ML-KEM-768.
- Phase B (Q4 2026): TPM attestation signature mode plumbing for RSA and XMSS mode selection.
- Phase C (2027): utility ledger dual-signature migration period and legacy-to-PQC balance migration transaction.

## Implemented in this sprint

### Phase A: PQC-Hybrid Transport

- Added `KEXMode` support in `internal/network/transport.go`.
- Added parser aliases (`hybrid`, `ml-kem-768`, etc.) and config validation.
- Added strict KEX parser and runtime config wiring in `cmd/node-agent` and `cmd/orchestrator` via `MOHAWK_TRANSPORT_KEX_MODE`.
- Added `/p2p/info` transport mode metadata (`kex_mode`, `expected_public_key_bytes`) and node/orchestrator compatibility checks.
- Added KEX-aware gradient stream envelopes with explicit mode negotiation and keyshare-size enforcement (`x25519=32`, `x25519-mlkem768-hybrid=1216`).
- Added expected public-key size metadata:
  - `x25519`: 32 bytes
  - `x25519-mlkem768-hybrid`: 1216 bytes

### Phase B: TPM-Bound PQC Identity

- Added attestation signature mode parsing in `internal/tpm/tpm.go`:
  - `xmss` (default)
  - `rsa-pss-sha256` (compatibility mode)
- Extended quote envelope with `signature_algo`.
- Updated verifier to route by signature algorithm.
- Implemented stateful hash-signature generation/verification path for `xmss` mode with replay index checks.
- Bound XMSS metadata (`signature_algo`, `signature_index`, `hash_sig_key_id`) into the signed payload digest to prevent metadata tampering.
- Added deterministic hash-signature seed loading controls (`MOHAWK_TPM_HASHSIG_SEED_HEX`, `MOHAWK_TPM_HASHSIG_SEED_FILE`, `MOHAWK_TPM_HASHSIG_REQUIRE_SEEDED`).
- Updated `cmd/tpm-metrics` health endpoint to report active attestation signature mode.

### Phase C: Ledger Migration

- Added migration transaction type `migrate`.
- Added dual-signature migration operation:
  - `MigrateWithDualSignature(legacy, pqc, amount, memo, legacySigned, pqcSigned)`
- Added migration period controls:
  - `EnablePQCMigration(enabled, eta)`
  - `ConfigurePQCMigration(enabled, eta, lockLegacyTransfers)`
  - `PQCMigrationStatus()`
- Added optional legacy transfer lock during migration cutover (prevents post-migration sends/burns from migrated legacy accounts).
- Added migration idempotency + nonce replay controls via `MigrateWithDualSignatureControls`.
- Added persistent migration state fields in ledger snapshots.
- Added cryptographic migration verification API via `MigrateWithDualSignatureCryptographic`.
- Added canonical migration signing digest for dual-signature payloads (`MigrationSigningDigest`).
- Added legacy signature verification (`ecdsa-p256-sha256`) and PQC compatibility verification path (`ml-dsa-*` aliases via Ed25519 compatibility verifier).

### Orchestrator Admin Surface

- Added migration operations API endpoints:
  - `GET /ledger/migration/status`
  - `POST /ledger/migration/config`
  - `POST /ledger/migration/digest`
  - `POST /ledger/migration/migrate`
- Added optional bearer auth for admin routes via `MOHAWK_ADMIN_TOKEN`.

## Benchmark impact tracking targets

- Proof verification: expected negligible impact.
- Handshake latency: monitor +2ms to +5ms target band when hybrid mode is enabled.
- Network overhead: watch public-key growth from 32 bytes to ~1216 bytes in hybrid transport mode.

## Sprint closeout status

1. ✅ Hybrid transport negotiation wired at runtime gradient stream level with strict KEX metadata and keyshare-size validation.
2. ✅ XMSS quote path hardened with signed metadata binding and deterministic seed controls for operational rollout.
3. ✅ Dual-signature cryptographic migration validation added (legacy ECDSA + PQC compatibility verifier).
4. ✅ Migration epoch cutover controls added (`migration_epoch`, `require_crypto_epoch`) with post-epoch cryptographic enforcement.

## Major Release Completion Status

PQC readiness overhaul is now release-complete in the mainline repository:

1. ✅ Hybrid transport KEX enforcement is runtime-validated and surfaced in readiness evidence.
2. ✅ XMSS-capable TPM attestation mode is wired, reported, and checked in readiness policy gates.
3. ✅ Dual-signature migration path includes digest-first signing and cryptographic verification fields.
4. ✅ One-click production gate defaults to strict host kernel preflight with structured report artifacts.

## Local-only workflow

- No remote pushes are required.
- Continue development and validation on this branch only.
