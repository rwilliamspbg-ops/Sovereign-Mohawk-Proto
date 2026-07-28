# Root Document Relocation Plan

## Objective

Reduce root-directory documentation clutter while preserving operational behavior, CI stability, and discoverability.

## Scope

- Move low-risk, archival, and execution-summary markdown files from repository root into `docs/archive/root-cleanup-2026-04/`.
- Keep canonical root files in place (`README.md`, `LICENSE.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, and other high-traffic docs).
- Update indexes so relocated artifacts remain discoverable.

## Relocation Criteria

A file qualifies for relocation when one or more apply:

1. It is historical status/report material and not a canonical entrypoint.
2. It has no hardcoded references from CI workflows or runtime paths.
3. It has zero or minimal cross-repo references, or references can be safely updated.

## Pass 1 (Completed)

Relocated files:

- `COMPLETE_CONFIRMATION.md`
- `FINAL_COMPREHENSIVE_VALIDATION.md`
- `MACHINE_VERIFICATION_COMPLETE.md`
- `PRODUCTION_PUSH_COMPLETE.md`
- `PR_3_DESCRIPTION.md`
- `PR_CREATION_SUMMARY.md`

## Pass 2 (Completed)

Relocated files:

- `EASE_OF_USE_IMPROVEMENT_PLAN.md`
- `FULL_FORMAL_VALIDATION_ANALYSIS.md`
- `GA_CUT_RUNBOOK_v1.0.0.md`
- `LOCAL_COMPREHENSIVE_TEST_RESULTS.md`
- `MACHINE_VALIDATION_IMPLEMENTATION_PLAN.md`
- `SECURITY_SETTINGS_VERIFICATION.md`
- `SPRINT_PQC_BUILD_LOCAL.md`
- `UPGRADE_IMPLEMENTATION_PLAN_2026_2027.md`

## Pass 3 (Completed)

Relocated files:

- `COMPREHENSIVE_PERFORMANCE_AND_STRESS_TEST_REPORT.md`
- `DOCUMENTATION_INDEX_AND_NAVIGATION.md`
- `EU_DATABASE_REGISTRATION_PLAN.md`
- `EXECUTION_SUMMARY_SDK_EXPANSION.md`
- `FINAL_TEST_RESULTS_SUMMARY.md`
- `FORMAL_VALIDATION_TEST_REPORT.md`
- `MASTER_COMPLETION_REPORT.md`

Deferred files (kept in root for now):

- `TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md` (referenced by lint configuration)
- `VALIDATION_SIGN_OFF.md` (referenced by local comprehensive test validation)

## Breakage Re-evaluation

Current relocation set is documentation-only and does not modify executable code, workflow logic, or runtime configuration.

Checks performed:

1. Verified moved pass-2 files were unreferenced before relocation.
2. Preserved prior pass-1 index links and expanded docs index.
3. Reconfirmed known workflow dependency risks remain unrelated to pass-2 files (for example, `docs/BENCHMARKS_AND_REPRODUCIBILITY.md` and `docs/ADOPTION_ACCELERATION_PLAN.md` are still required by release packaging workflow).
4. Repeated reference-scan and stale-path rewrites for pass-3 files.
5. Preserved lint/test-sensitive root files that are consumed by repository validation scripts.

Result:

- No expected functional breakage from passes 1-3.
- Primary risk class remains stale links for future non-indexed moves; mitigate via grep-based path checks before each relocation batch.

## Pass 4 (Completed, July 2026)

Root markdown sprawl had grown back to 233 tracked files by this point (only ~30 had
been addressed by Passes 1-3). This pass took a systematic approach instead of a
manually curated batch:

1. Defined a canonical keep-at-root list (README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT,
   SECURITY, CHANGELOG, CONTRIBUTORS, NOTICE, ROADMAP, COMPLIANCE, DEPENDENCIES,
   PERFORMANCE, NAMING, DASHBOARD) plus files with confirmed CI/script dependencies on a
   root-relative path (FORMAL_TRACEABILITY_MATRIX.md, TESTING_AND_PERFORMANCE_VALIDATION_COMPLETE.md,
   VALIDATION_SIGN_OFF.md, BLOG_POST_FORMAL_PROOFS.md - the last three confirmed via
   `scripts/ci/lint_formal_proof_claims.py`).
2. Defined a "move to docs/" list for durable reference/technical material that isn't a
   session status log (WHITE_PAPER.md, ACADEMIC_PAPER.md/.pdf, differential_privacy.md,
   OPERATIONS_RUNBOOK.md, SUPPLY_CHAIN_SECURITY.md, HARDWARE_COMPATIBILITY.md,
   QMS_SYSTEM_MANUAL.md, PUBLIC_ARTIFACTS.md, FIPS_PROFILE_SCOPE.md,
   EDGE_LITE_RESOURCE_PROFILE.md, COMPLIANCE_MAPPING.md, CONFORMITY_ASSESSMENT_AND_CE_PATH.md,
   POST_MARKET_MONITORING_AND_INCIDENT_REPORTING.md, PROTOCOL_ANALYSIS_THROUGHPUT_LIMITS.md,
   UNIFIED_AUTH_QUICK_REFERENCE.md, AUTH_LAYER_IMPLEMENTATION_GUIDE.md,
   AUDITOR_QUICK_REFERENCE.md, CERTIK_AUDIT_SUMMARY.md, RELEASE_NOTES_PQC_OVERHAUL.md).
3. Grep-checked the remaining 196 files against `.github/workflows/`, `scripts/`,
   `Makefile`, and `docker-compose*.yml` for path references before moving - none found.
4. Moved all 196 remaining files to `docs/archive/root-cleanup-2026-07/` via `git mv`
   (full history preserved), with an inventory index at
   [archive/root-cleanup-2026-07/README.md](archive/root-cleanup-2026-07/README.md).
5. Found and fixed real broken links this created: `README.md` and `ROADMAP.md` had
   live markdown links to `DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`,
   `TECHNICAL_DOCUMENTATION_FILE.md`, and `RELEASE_CHECKLIST_v1.0.0_RC.md` (repointed to
   the new archive path); `docs/AUDITOR_QUICK_REFERENCE.md` linked
   `FORMAL_VERIFICATION_COVERAGE.md` (repointed). Remaining filename mentions elsewhere
   (CHANGELOG.md entries, DoD_Alignment_Addendum.md evidence citations) are prose
   references to historical artifacts, not live links, and were left as-is.

Result: root tracked markdown count went from 233 to 18 (see the keep list above) plus
2 pre-existing untracked working files left untouched.

## Follow-up Backlog

Potential next candidates should be handled in smaller batches with path-rewrite checks:

- Release/process reports with low reference counts.
- Older sprint and phase summaries.
- Legacy PR planning documents still in root.

Use this sequence for each future batch:

1. Count references (`grep -RIn`).
2. Move files to `docs/archive/root-cleanup-2026-04/`.
3. Update index links.
4. Re-scan for stale paths.
5. Validate CI workflow doc path dependencies are unaffected.
