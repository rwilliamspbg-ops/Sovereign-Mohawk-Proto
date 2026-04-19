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

## XMSS Stateful Operations Addendum

- Rotation cadence: quarterly in production, or immediately after suspected key-state compromise.
- Index-limit alerting thresholds:
  - warning at 80%
  - escalation at 90%
  - mandatory rollover before 100%
- Secondary tree rollover:
  - pre-stage secondary seed/public key
  - temporary dual-trust verification window
  - controlled signer switch and SLO observation
  - old-tree trust revocation with archived evidence

## Release Evidence Artifacts

## Performance Evidence

Performance Evidence: [Release performance index](results/metrics/release_performance_evidence.md), [FedAvg benchmark compare](results/metrics/fedavg_benchmark_compare.md), and [Bridge compression benchmark](results/metrics/bridge_compression_benchmark_compare.md).

- `results/readiness/one-click-pipeline-report.json`
- `results/readiness/one-click-pipeline-report.md`
- `results/go-live/evidence/go_toolchain_alignment_2026-03-31.md`
- `results/readiness/readiness-report.json`
- `results/readiness/readiness-digest.md`
- `chaos-reports/*-summary.json`

## Readiness Outcome (Latest Run)

- Strict mode correctly blocks on insufficient host buffers in this dev container.
- Advisory override completes full pipeline with `PASS` and generated artifacts.
- Go runtime/compiler alignment verified in one-click report (`go1.25.9` / `go1.25.9`).

## GA Documentation Addendum (2026-04-17)

The GA documentation and evidence package was refreshed after strict host tuning and final gate reruns.

- Consolidated readiness report: `captured_artifacts/ga_release_readiness_2026-04-17.md`
- Strict go-live snapshot (pass): `results/go-live/evidence/go_live_gate_strict_2026-04-17.json`
- Formal go-live report (strict): `results/go-live/go-live-gate-report.json`
- GA tag safety local check: `python3 scripts/enforce_ga_tag_safety.py --tag v1.0.0` (PASS)
- Canonical artifact summary: `captured_artifacts/artifact_evidence_summary.md`
- Canonical artifact manifest: `captured_artifacts/artifact_manifest_latest.json`
- Package checksum record: `captured_artifacts/release_package_manifest_checksums_2026-04-17.txt`
