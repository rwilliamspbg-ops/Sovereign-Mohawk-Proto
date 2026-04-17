# v1.0.0 Release Candidate Checklist

## Scope

This checklist is the formal release-candidate sign-off gate before cutting the v1.0.0 GA tag.

Status snapshot (2026-04-17): Runtime, security, operations, scale, and GA safety gates are passing with current evidence. Final release-owner tag approval remains the last governance action before tag cut.

## Gate 1: Runtime and Verification

- [x] `go test ./...` passes on release branch commit.
- [x] Python SDK tests pass (`cd sdk/python && python -m pytest tests/ -v`).
- [x] Formal go-live gate passes in strict mode (`make go-live-gate-strict`).
- [x] Golden path evidence run passes (`make golden-path-e2e`).

Evidence:

- [results/go-live/go-live-gate-report.json](results/go-live/go-live-gate-report.json)
- [results/go-live/evidence/go_live_gate_strict_2026-04-17.json](results/go-live/evidence/go_live_gate_strict_2026-04-17.json)
- [results/go-live/golden-path-report.json](results/go-live/golden-path-report.json)

## Gate 2: Security and Assurance

- [x] External security audit report attached, with no unresolved critical findings.
- [x] Penetration test report attached for orchestrator/API and bridge settlement.
- [x] Threat-model refresh evidence attached for mTLS and metrics planes.
- [x] Dependency baseline and patch-SLA evidence attached.
- [x] FIPS evidence bundle attached and approved (`results/go-live/evidence/fips_evidence_bundle_2026-04-05.md`, `results/go-live/attestations/fips_evidence_bundle.json`).

## Gate 3: Operations and SLOs

- [x] Versioned SLO/SLI baseline approved (`results/go-live/evidence/slo_sli_baseline_2026-03-28.md`).
- [x] Failure-injection latency validation passes (`results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md`).
- [x] Chaos recovery summaries attached for `grafana`, `orchestrator`, `prometheus`, and `tpm-metrics`.
- [x] Runbook and alert playbooks verified current (`OPERATIONS_RUNBOOK.md`).

## Gate 4: Scale and Performance Evidence

- [x] 1M-scale rehearsal evidence attached and signed off.
- [x] Release benchmark evidence index regenerated (`make release-performance-evidence`).
- [x] Bridge compression compare report attached.
- [x] FedAvg benchmark compare report attached.

Evidence:

- [results/metrics/release_performance_evidence.md](results/metrics/release_performance_evidence.md)
- [results/metrics/bridge_compression_benchmark_compare.md](results/metrics/bridge_compression_benchmark_compare.md)
- [results/metrics/fedavg_benchmark_compare.md](results/metrics/fedavg_benchmark_compare.md)

## Gate 5: TPM Attestation Production Readiness

- [x] TPM 2.0 quote/verify flow enabled in production mode.
- [x] Remote attestation evidence format hardening and replay protections verified.
- [x] Cross-platform attestation matrix evidence attached (Linux/Windows/macOS).

Gate 5 automation references:

- Workflow: [.github/workflows/tpm-production-signoff.yml](.github/workflows/tpm-production-signoff.yml)
- Bundle builder: [scripts/build_tpm_signoff_bundle.py](scripts/build_tpm_signoff_bundle.py)
- Closure validator: [scripts/validate_tpm_attestation_closure.py](scripts/validate_tpm_attestation_closure.py)

Gate 5 sign-off evidence (2026-04-11):

- [results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.md](results/go-live/evidence/tpm_attestation_cross_platform_matrix_2026-04-11.md)
- [results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.md](results/go-live/evidence/tpm_attestation_closure_validation_2026-04-11.md)
- [results/go-live/evidence/tpm_closure_summary_2026-04-11.md](results/go-live/evidence/tpm_closure_summary_2026-04-11.md)
- [results/go-live/attestations/tpm_attestation_production_closure.json](results/go-live/attestations/tpm_attestation_production_closure.json)

Suggested next items after Gate 5 sign-off:

- [ ] Promote TPM sign-off bundle archive as a release asset on GA tag cut.
- [ ] Add a nightly TPM production sign-off run (scheduled trigger) to detect regressions earlier.
- [ ] Add attestation evidence freshness alerting (fail if latest matrix is older than 7 days).

## Gate 6: Packaging and Rollout

- [x] Release notes finalized and linked to evidence artifacts.
- [x] Genesis-to-production deployment guide published (`DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`).
- [x] Release package manifest generated and checksum-verified.
- [ ] v1.0.0 GA tag approved by release owner.

Packaging evidence:

- [RELEASE_NOTES_PQC_OVERHAUL.md](RELEASE_NOTES_PQC_OVERHAUL.md)
- [captured_artifacts/artifact_manifest_latest.json](captured_artifacts/artifact_manifest_latest.json)
- [captured_artifacts/artifact_evidence_summary.md](captured_artifacts/artifact_evidence_summary.md)
- [captured_artifacts/release_package_manifest_checksums_2026-04-17.txt](captured_artifacts/release_package_manifest_checksums_2026-04-17.txt)
- [captured_artifacts/ga_release_readiness_2026-04-17.md](captured_artifacts/ga_release_readiness_2026-04-17.md)

## Approval Record

- Release owner:
- Security owner:
- Platform owner:
- Date: 2026-04-17 (documentation pass completed)
