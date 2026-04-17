# Artifact Governance

This document defines how generated evidence artifacts are retained, summarized, and reviewed.

## Policy

1. Separate code and generated evidence in review flow.
2. Keep only canonical validation runs in the active working set.
3. Archive older validation runs instead of keeping all files live.
4. Publish a compact summary and manifest for reviewers.

## Canonical Artifact Set

- Validation runs: latest `fast` and latest `deep` under `test-results/full-validation/`.
- Go-live evidence: latest TPM closure summary in `results/go-live/evidence/`.
- Release evidence: `results/metrics/release_performance_evidence.md`.
- API contract: `results/api/openapi.json`.
- Forensics evidence: `results/forensics/byzantine_rejections_local.md` and metrics JSON.

## Retention Standard

- Keep latest `ARTIFACT_KEEP` validation runs per profile (`fast`, `deep`) in active storage.
- Archive older validation runs to `results/archive/full-validation/` as compressed tarballs.
- Default project setting: `ARTIFACT_KEEP=3` in [Makefile](../Makefile).

## Automation

Use `scripts/manage_artifacts.sh` directly or via Make targets:

```bash
# Preview what would be archived
make artifact-retention-dryrun

# Archive old runs and remove them from active test-results
make artifact-retention-apply

# Regenerate canonical summary + manifest
make artifact-summary

# Optional override
make artifact-summary ARTIFACT_KEEP=2
```

Generated summary outputs:

- `captured_artifacts/artifact_evidence_summary.md`
- `captured_artifacts/artifact_manifest_latest.json`

## PR Guidance

1. Keep code changes in one PR and bulk generated evidence in a separate evidence PR when possible.
2. Reference canonical outputs from `captured_artifacts/artifact_evidence_summary.md` in PR descriptions.
3. Only force-add ignored generated outputs when they are intentionally curated release evidence.
4. Use the artifact-review checklist in [PULL_REQUEST_TEMPLATE.md](../.github/PULL_REQUEST_TEMPLATE.md).
