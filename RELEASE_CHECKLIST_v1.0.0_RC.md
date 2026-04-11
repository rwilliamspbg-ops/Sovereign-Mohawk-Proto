# v1.0.0 Release Candidate Checklist

## Scope

This checklist is the formal release-candidate sign-off gate before cutting the v1.0.0 GA tag.

## Gate 1: Runtime and Verification

- [ ] `go test ./...` passes on release branch commit.
- [ ] Python SDK tests pass (`cd sdk/python && python -m pytest tests/ -v`).
- [ ] Formal go-live gate passes in strict mode (`make go-live-gate-strict`).
- [ ] Golden path evidence run passes (`make golden-path-e2e`).

## Gate 2: Security and Assurance

- [ ] External security audit report attached, with no unresolved critical findings.
- [ ] Penetration test report attached for orchestrator/API and bridge settlement.
- [ ] Threat-model refresh evidence attached for mTLS and metrics planes.
- [ ] Dependency baseline and patch-SLA evidence attached.
- [ ] FIPS evidence bundle attached and approved (`results/go-live/evidence/fips_evidence_bundle_2026-04-05.md`, `results/go-live/attestations/fips_evidence_bundle.json`).

## Gate 3: Operations and SLOs

- [ ] Versioned SLO/SLI baseline approved (`results/go-live/evidence/slo_sli_baseline_2026-03-28.md`).
- [ ] Failure-injection latency validation passes (`results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md`).
- [ ] Chaos recovery summaries attached for `grafana`, `orchestrator`, `prometheus`, and `tpm-metrics`.
- [ ] Runbook and alert playbooks verified current (`OPERATIONS_RUNBOOK.md`).

## Gate 4: Scale and Performance Evidence

- [ ] 1M-scale rehearsal evidence attached and signed off.
- [ ] Release benchmark evidence index regenerated (`make release-performance-evidence`).
- [ ] Bridge compression compare report attached.
- [ ] FedAvg benchmark compare report attached.

## Gate 5: TPM Attestation Production Readiness

- [ ] TPM 2.0 quote/verify flow enabled in production mode.
- [ ] Remote attestation evidence format hardening and replay protections verified.
- [ ] Cross-platform attestation matrix evidence attached (Linux/Windows/macOS).

Gate 5 automation references:

- Workflow: [.github/workflows/tpm-production-signoff.yml](.github/workflows/tpm-production-signoff.yml)
- Bundle builder: [scripts/build_tpm_signoff_bundle.py](scripts/build_tpm_signoff_bundle.py)
- Closure validator: [scripts/validate_tpm_attestation_closure.py](scripts/validate_tpm_attestation_closure.py)

## Gate 6: Packaging and Rollout

- [ ] Release notes finalized and linked to evidence artifacts.
- [ ] Genesis-to-production deployment guide published (`DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`).
- [ ] Release package manifest generated and checksum-verified.
- [ ] v1.0.0 GA tag approved by release owner.

## Approval Record

- Release owner:
- Security owner:
- Platform owner:
- Date:
