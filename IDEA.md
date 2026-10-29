Formal Verification Status
Lean source of truth: proofs/LeanFormalization.lean
Theorem modules: proofs/LeanFormalization/
Traceability matrix (theorem claim → Lean module → runtime test evidence → status): proofs/FORMAL_TRACEABILITY_MATRIX.md — start here first; it tracks 15 claims, each with its own status (fully_formalized, surrogate_verified_*, model_verified, or Phase 4 model) and, where relevant, an explicit note on what is not yet proven. Read the Notes column, not just the Status column — several entries carry caveats that qualify the headline status.
Machine-checkable formal validation report: results/proofs/formal_validation_report.json
Verification bundle manifest + archive: results/proofs/formal-verification-bundle/bundle_manifest.json, results/proofs/formal-verification-bundle.tar.gz
Independent verifier guide: docs/FORMAL_VERIFICATION_GUIDE.md
Required CI formal proof gate (blocks merge to main): .github/workflows/full-validation-pr-gate.yml (full-validation-fast, which builds the full Lean suite and runs the vacuous-theorem lint)
Additional, non-required Lean workflows (same checks plus artifact/bundle generation, run for visibility but do not block merge): .github/workflows/verify-proofs.yml (verify-lean-formalization), .github/workflows/verify-formal-proofs.yml
Mathlib disk-space safeguard in CI: all three jobs above run pre-build runner cleanup before Lean/Lake build steps
Latest local verification log (build + placeholder scan): proofs/manual_verify.log
Formal report and bundle checks:

make refresh-formal-validation
make validate-formal
make validate-formal-tooling-tests
make validate-formal-container
make package-formal-verification-artifacts
