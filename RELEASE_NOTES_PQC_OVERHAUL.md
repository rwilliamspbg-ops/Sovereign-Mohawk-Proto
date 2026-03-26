# PQC Readiness Overhaul — Major Release Notes

Date: 2026-03-26

## Release Summary

This release completes the Sovereign-Mohawk 2026–2027 post-quantum readiness program and moves the repository from migration scaffolding to production-enforced controls.

## What Is Now Enforced

- Hybrid transport KEX policy defaults to `x25519-mlkem768-hybrid` with keyshare-size validation in gradient stream envelopes.
- TPM identity attestation defaults to `xmss`, with XMSS metadata binding in quote payload digest computation.
- Ledger migration supports canonical digest-first signing and cryptographic dual-signature submission.
- Migration epoch cutover now supports post-epoch cryptographic-only enforcement.
- One-click pipeline emits structured pipeline pass/fail reports with Go toolchain alignment metadata.

## Operator-Facing API Additions

- `POST /ledger/migration/digest`
  - Returns canonical digest payload (`digest_hex`) and normalized `amount_units` for signing.
- `POST /ledger/migration/migrate`
  - Accepts cryptographic signature fields:
    - Legacy: `legacy_algo`, `legacy_pub_key`, `legacy_sig`
    - PQC: `pqc_algo`, `pqc_pub_key`, `pqc_sig`

## Default PQC Runtime Profile

- `MOHAWK_TRANSPORT_KEX_MODE=x25519-mlkem768-hybrid`
- `MOHAWK_TPM_IDENTITY_SIG_MODE=xmss`
- `MOHAWK_PQC_MIGRATION_ENABLED=true`
- `MOHAWK_PQC_LOCK_LEGACY_TRANSFERS=true`
- `MOHAWK_PQC_MIGRATION_EPOCH=2027-12-31T00:00:00Z`
- `MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH=true`

## One-Click Pipeline Policy

- Host preflight now defaults to strict mode:
  - `MOHAWK_HOST_PREFLIGHT_MODE=strict`
- Dev-container override remains available:
  - `MOHAWK_HOST_PREFLIGHT_MODE=advisory make mainnet-one-click`

## Production Host Kernel Checklist (Required)

Apply:

- `sudo sysctl -w net.core.rmem_max=8388608`
- `sudo sysctl -w net.core.rmem_default=262144`
- `sudo sysctl -w net.core.wmem_max=8388608`
- `sudo sysctl -w net.core.wmem_default=262144`

Persist:

1. Add the keys above to `/etc/sysctl.conf` or `/etc/sysctl.d/99-mohawk-network.conf`
2. Run `sudo sysctl --system`
3. Verify with `./scripts/validate_host_network_tuning.sh`

## Release Evidence Artifacts

- `results/readiness/one-click-pipeline-report.json`
- `results/readiness/one-click-pipeline-report.md`
- `results/readiness/readiness-report.json`
- `results/readiness/readiness-digest.md`
- `chaos-reports/*-summary.json`

## Readiness Outcome (Latest Run)

- Strict mode correctly blocks on insufficient host buffers in this dev container.
- Advisory override completes full pipeline with `PASS` and generated artifacts.
- Go runtime/compiler alignment verified in one-click report (`go1.25.7` / `go1.25.7`).
