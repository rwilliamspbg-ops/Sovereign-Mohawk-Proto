# PQC Sprint Build (Local Only)

Branch: `feature/pqc-hybrid-sprint-build`

## Scope

This sprint bootstraps implementation for the 2026–2027 PQC migration plan using safe, incremental hooks:

- Phase A (Q3 2026): libp2p transport KEX mode hooks for X25519 and Hybrid X25519+ML-KEM-768.
- Phase B (Q4 2026): TPM attestation signature mode plumbing for RSA and XMSS mode selection.
- Phase C (2027): utility ledger dual-signature migration period and legacy-to-PQC balance migration transaction.

## Implemented in this sprint kickoff

### Phase A: PQC-Hybrid Transport

- Added `KEXMode` support in `internal/network/transport.go`.
- Added parser aliases (`hybrid`, `ml-kem-768`, etc.) and config validation.
- Added strict KEX parser and runtime config wiring in `cmd/node-agent` and `cmd/orchestrator` via `MOHAWK_TRANSPORT_KEX_MODE`.
- Added `/p2p/info` transport mode metadata (`kex_mode`, `expected_public_key_bytes`) and node/orchestrator compatibility checks.
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

### Orchestrator Admin Surface

- Added migration operations API endpoints:
  - `GET /ledger/migration/status`
  - `POST /ledger/migration/config`
  - `POST /ledger/migration/migrate`
- Added optional bearer auth for admin routes via `MOHAWK_ADMIN_TOKEN`.

## Benchmark impact tracking targets

- Proof verification: expected negligible impact.
- Handshake latency: monitor +2ms to +5ms target band when hybrid mode is enabled.
- Network overhead: watch public-key growth from 32 bytes to ~1216 bytes in hybrid transport mode.

## Next implementation tasks

1. Wire actual hybrid KEX handshake in libp2p security transport negotiation path.
2. Integrate real TPM-backed XMSS/LMS signer + verifier path.
3. Add dual-signature cryptographic validation for migration transactions (legacy ECDSA + ML-DSA).
4. Add migration epoch controls and replay protection for on-chain hard-fork cutover.

## Local-only workflow

- No remote pushes are required.
- Continue development and validation on this branch only.
