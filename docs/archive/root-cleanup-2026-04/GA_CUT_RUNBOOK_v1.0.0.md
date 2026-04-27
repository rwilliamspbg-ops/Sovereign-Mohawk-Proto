# v1.0.0 GA Cut Runbook (One-Pass)

## Objective

Execute v1.0.0 GA cut in one controlled pass: validate gates, refresh evidence, tag, publish, and verify release assets.

## Operator Profile

- Release owner with push access to main and tag creation rights.
- GitHub CLI authenticated with repo write permissions.
- Run on a production-tuned host (strict host preflight must pass).

## Hard Stop Rules

- Stop immediately on first failing command.
- Do not cut GA tag until strict gate evidence and GA tag safety check pass.
- Do not override failing checks.

## One-Pass Command Sequence

Run from repository root.

```bash
#!/usr/bin/env bash
set -euo pipefail

TAG="v1.0.0"
STAMP="$(date -u +%Y-%m-%d)"
STRICT_SNAPSHOT="results/go-live/evidence/go_live_gate_strict_${STAMP}.json"
ADVISORY_SNAPSHOT="results/go-live/evidence/go_live_gate_advisory_${STAMP}.json"
TPM_VALIDATION_JSON="results/go-live/evidence/tpm_attestation_closure_validation_${STAMP}.json"
TPM_VALIDATION_MD="results/go-live/evidence/tpm_attestation_closure_validation_${STAMP}.md"
TPM_SUMMARY_JSON="results/go-live/evidence/tpm_closure_summary_${STAMP}.json"
TPM_SUMMARY_MD="results/go-live/evidence/tpm_closure_summary_${STAMP}.md"
PKG_CHECKSUMS="results/go-live/evidence/release_package_manifest_checksums_${STAMP}.txt"
TPM_BUNDLE_TAR="results/go-live/evidence/tpm_signoff_bundle_${STAMP}.tar.gz"
FORMAL_RELEASE_CHECKSUMS="results/go-live/evidence/formal_verification_release_checksums_${STAMP}.txt"

# 0) Repo and auth sanity

git fetch --tags --prune origin

test -z "$(git status --porcelain)"

gh auth status

# 1) Runtime and SDK gates (Gate 1)

source scripts/ensure_go_toolchain.sh

go test -count=1 ./...

make test-python-sdk

# 2) Formal go-live gate strict (Gate 1 critical)

make go-live-gate-strict

cp results/go-live/go-live-gate-report.json "${STRICT_SNAPSHOT}"

jq -e '.ok == true and .host_preflight_mode == "strict"' "${STRICT_SNAPSHOT}" >/dev/null

# 3) Advisory snapshot for closure summary continuity

make go-live-gate-advisory

cp results/go-live/go-live-gate-report.json "${ADVISORY_SNAPSHOT}"

jq -e '.ok == true and .host_preflight_mode == "advisory"' "${ADVISORY_SNAPSHOT}" >/dev/null

# 4) Golden path and ops/perf evidence (Gates 1, 3, 4)

make golden-path-e2e
jq -e '.ok == true' results/go-live/golden-path-report.json >/dev/null

make failure-injection-latency-check

make release-performance-evidence

make capability-dashboard-matrix

# 5) TPM closure refresh and GA safety enforcement (Gate 5 + GA policy)

LATEST_TPM_MATRIX_JSON="$(ls results/go-live/evidence/tpm_attestation_cross_platform_matrix_*.json | sort | tail -n 1)"

python3 scripts/validate_tpm_attestation_closure.py \
  --matrix "${LATEST_TPM_MATRIX_JSON}" \
  --attestation results/go-live/attestations/tpm_attestation_production_closure.json \
  --output-json "${TPM_VALIDATION_JSON}" \
  --output-md "${TPM_VALIDATION_MD}"

python3 scripts/generate_tpm_closure_summary.py \
  --output-json "${TPM_SUMMARY_JSON}" \
  --output-md "${TPM_SUMMARY_MD}"

make ga-tag-ready-check

# 6) Release package manifest + checksums (Gate 6)

make artifact-summary

make package-formal-verification-artifacts

sha256sum \
  captured_artifacts/artifact_manifest_latest.json \
  captured_artifacts/artifact_evidence_summary.md \
  | tee "${PKG_CHECKSUMS}"

sha256sum \
  release-assets/formal/formal_validation_report.json \
  release-assets/formal/formal-verification-bundle.tar.gz \
  release-assets/formal/bundle_manifest.json \
  release-assets/formal/sha256sums.txt \
  | tee "${FORMAL_RELEASE_CHECKSUMS}"

# 7) Commit refreshed GA evidence before tag

git add \
  results/go-live/go-live-gate-report.json \
  results/go-live/evidence/go_live_gate_strict_*.json \
  results/go-live/evidence/go_live_gate_advisory_*.json \
  results/go-live/golden-path-report.json \
  results/go-live/golden-path-report.md \
  results/go-live/evidence/tpm_attestation_closure_validation_*.json \
  results/go-live/evidence/tpm_attestation_closure_validation_*.md \
  results/go-live/evidence/tpm_closure_summary_*.json \
  results/go-live/evidence/tpm_closure_summary_*.md \
  results/go-live/evidence/release_package_manifest_checksums_*.txt \
  results/go-live/evidence/formal_verification_release_checksums_*.txt \
  results/metrics/release_performance_evidence.md \
  results/go-live/capability_dashboard_matrix.md \
  captured_artifacts/artifact_manifest_latest.json \
  captured_artifacts/artifact_evidence_summary.md

git commit -m "release: refresh GA evidence bundle for ${TAG}"

git push origin main

# 8) Cut GA tag

git tag -a "${TAG}" -m "Sovereign Mohawk ${TAG} GA"

git push origin "${TAG}"

# 9) Monitor GA workflows (tag safety + release assets)

GA_RUN_ID="$(gh run list --workflow "GA Tag Safety" --event push --limit 1 --json databaseId --jq '.[0].databaseId')"
RA_RUN_ID="$(gh run list --workflow "Release Assets and Images" --event push --limit 1 --json databaseId --jq '.[0].databaseId')"

gh run watch "${GA_RUN_ID}"

gh run watch "${RA_RUN_ID}"

# 10) Verify release object exists

gh release view "${TAG}"

# 11) Promote TPM sign-off bundle as GA release asset

tar -czf "${TPM_BUNDLE_TAR}" \
  "${LATEST_TPM_MATRIX_JSON}" \
  "${TPM_VALIDATION_JSON}" \
  "${TPM_VALIDATION_MD}" \
  "${TPM_SUMMARY_JSON}" \
  "${TPM_SUMMARY_MD}" \
  results/go-live/attestations/tpm_attestation_production_closure.json

gh release upload "${TAG}" "${TPM_BUNDLE_TAR}" --clobber

# 12) Promote formal verification artifacts as GA release assets

gh release upload "${TAG}" \
  release-assets/formal/formal_validation_report.json \
  release-assets/formal/formal-verification-bundle.tar.gz \
  release-assets/formal/bundle_manifest.json \
  release-assets/formal/sha256sums.txt \
  "${FORMAL_RELEASE_CHECKSUMS}" \
  --clobber

echo "GA cut complete for ${TAG}"
```

## Artifact Checklist (Sign-Off)

Check all items after the command sequence completes.

### Gate 1: Runtime and Verification

- [ ] go test passed on release commit.
- [ ] Python SDK tests passed.
- [ ] Strict go-live gate report exists and passes:
  - results/go-live/go-live-gate-report.json
  - results/go-live/evidence/go_live_gate_strict_YYYY-MM-DD.json
- [ ] Golden path report exists and ok is true:
  - results/go-live/golden-path-report.json
  - results/go-live/golden-path-report.md

### Gate 2: Security and Assurance

- [ ] All required attestation files are approved:
  - results/go-live/attestations/security_audit.json
  - results/go-live/attestations/penetration_test.json
  - results/go-live/attestations/threat_model_refresh.json
  - results/go-live/attestations/dependency_sla_baseline.json
  - results/go-live/attestations/fips_evidence_bundle.json
  - results/go-live/attestations/backup_restore_drill.json
  - results/go-live/attestations/soak_scale_rehearsal.json
  - results/go-live/attestations/incident_escalation_drill.json
  - results/go-live/attestations/runbook_published.json

### Gate 3: Operations and SLOs

- [ ] Failure-injection validation report exists and passes:
  - results/go-live/evidence/failure_injection_latency_validation_2026-03-28.json
  - results/go-live/evidence/failure_injection_latency_validation_2026-03-28.md
- [ ] Runbook is current:
  - OPERATIONS_RUNBOOK.md

### Gate 4: Scale and Performance Evidence

- [ ] Release performance evidence regenerated:
  - results/metrics/release_performance_evidence.md
- [ ] Benchmark compare artifacts present:
  - results/metrics/bridge_compression_benchmark_compare.md
  - results/metrics/fedavg_benchmark_compare.md

### Gate 5: TPM Production Closure

- [ ] TPM production attestation is approved:
  - results/go-live/attestations/tpm_attestation_production_closure.json
- [ ] TPM closure validation report exists for cut date and passes:
  - results/go-live/evidence/tpm_attestation_closure_validation_YYYY-MM-DD.json
  - results/go-live/evidence/tpm_attestation_closure_validation_YYYY-MM-DD.md
- [ ] TPM closure summary exists for cut date and ga_ready is true:
  - results/go-live/evidence/tpm_closure_summary_YYYY-MM-DD.json
  - results/go-live/evidence/tpm_closure_summary_YYYY-MM-DD.md
- [ ] TPM bundle uploaded to GA release:
  - results/go-live/evidence/tpm_signoff_bundle_YYYY-MM-DD.tar.gz

### Gate 6: Packaging and Rollout

- [ ] Canonical package manifest and summary regenerated:
  - captured_artifacts/artifact_manifest_latest.json
  - captured_artifacts/artifact_evidence_summary.md
- [ ] SHA-256 checksum record generated:
  - results/go-live/evidence/release_package_manifest_checksums_YYYY-MM-DD.txt
- [ ] Formal verification release checksums generated:
  - results/go-live/evidence/formal_verification_release_checksums_YYYY-MM-DD.txt
- [ ] GA tag exists and workflows passed:
  - GA Tag Safety workflow: PASS
  - Release Assets and Images workflow: PASS
- [ ] Formal verification artifacts uploaded to GA release:
  - release-assets/formal/formal_validation_report.json
  - release-assets/formal/formal-verification-bundle.tar.gz
  - release-assets/formal/bundle_manifest.json
  - release-assets/formal/sha256sums.txt

## Recovery / Abort Procedure

If any gate fails:

1. Delete local tag if created:
   - git tag -d v1.0.0
2. Delete remote tag if already pushed:
   - git push origin :refs/tags/v1.0.0
3. Open blocker issue with failing artifact path and command output.
4. Re-run this runbook from Step 1 after remediation.
