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
