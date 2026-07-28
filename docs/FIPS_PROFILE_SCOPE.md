# FIPS Profile Scope and Crypto Module Inventory

## Profile Scope Statement

This repository currently enforces a transitional FIPS posture with Go runtime FIPS mode controls:

- Transitional baseline: FIPS 140-2 aligned operational controls where applicable.
- Target state: FIPS 140-3 aligned release evidence and module-boundary inventory.

Production profile requirements:

- `GODEBUG=fips140=on`
- `MOHAWK_FIPS_REQUIRED=true`
- Runtime startup gate must fail if FIPS is required and unavailable.

## Cryptographic Module Boundary Inventory

| Boundary | Primary Files | Cryptographic Role | Notes |
| --- | --- | --- | --- |
| Runtime startup FIPS gate | `internal/startup/fips.go`, `cmd/orchestrator/main.go` | Enforce runtime FIPS posture and startup policy | Blocks startup when required mode is not enabled |
| TLS control plane | `cmd/orchestrator/main.go`, `internal/tpm/tpm.go` | mTLS server/client channel security | Covered by FIPS regression TLS handshake test |
| Manifest and migration signatures | `internal/manifest/manifest.go`, `internal/token/migration_signatures.go` | Ed25519 + ECDSA signature verification paths | Migration digest/signature path fuzz and property tests included |
| TPM attestation signature path | `internal/tpm/tpm.go`, `cmd/tpm-metrics/main.go` | TPM quote signing and verification modes | XMSS mode posture tracked in readiness checks |
| WASM hot-reload integrity | `internal/pyapi/api.go`, `internal/wasmhost/integrity.go` | Required hash + signature verification before load | Rejects unsigned or hash-mismatched inline reload payloads |

## Algorithm Usage Table

| Use Case | Algorithms | Enforcement |
| --- | --- | --- |
| TLS transport and control plane | TLS 1.2+ with platform crypto provider | `test/fips_regression_test.go` |
| Legacy migration signature path | ECDSA P-256 SHA-256 | `test/pqc_migration_fuzz_test.go` and `test/utility_coin_test.go` |
| PQC migration compatibility path | ML-DSA compatibility aliases mapped to Ed25519 verifier path | `test/pqc_migration_fuzz_test.go` |
| TPM identity signatures | XMSS mode default, RSA fallback compatibility | Readiness and TPM metrics checks |
| WASM hot-reload provenance | SHA-256 + Ed25519 | `internal/wasmhost/integrity_test.go` |

## Evidence Artifacts

- `results/go-live/evidence/fips_evidence_bundle_2026-04-05.md`
- `results/go-live/attestations/fips_evidence_bundle.json`
- `scripts/fips_runtime_check/main.go`
- `test/fips_regression_test.go`
