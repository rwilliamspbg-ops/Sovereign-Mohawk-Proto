# Formal Proof Traceability Matrix

Authoritative cross-reference between theorem claims, human-readable proofs, machine-checked Lean 4 modules, and runtime test evidence.

> **Phase 2 Note**: All proofs use concrete arithmetic and inductive tactics. Deeper probabilistic formalization is planned for Phase 3b.

## Scope

- Lean project root: `proofs/`
- Main import entry: `proofs/LeanFormalization.lean`
- Build command: `cd proofs && lake build LeanFormalization`

## Mapping

| # | Claim (Short) | Claim Source | Lean Module | Key Machine-Checked Theorems | Runtime Test Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 55.5% Byzantine resilience via hierarchical Multi-Krum at 10M node scale | [proofs/bft_resilience.md](bft_resilience.md) | `LeanFormalization/Theorem1BFT.lean` | `theorem1_half_bound_of_forall_cons`, `theorem1_half_bound_of_forall`, `theorem1_five_ninths_of_half_bound`, `theorem1_tier_majority_checked`, `theorem1_global_bound_checked`, `theorem1_ten_million_corollary` | `internal/multikrum_test.go::TestMultiKrumSelect`, `internal/aggregator_multikrum_test.go::TestProcessGradientBatchWithMultiKrum` | Verified | Concrete numeric bounds; deterministic model only |
| 2 | Integer composition surrogate for a 4-tier privacy-budget profile | [proofs/differential_privacy.md](differential_privacy.md) | `LeanFormalization/Theorem2RDP.lean` | `theorem2_composition_append`, `theorem2_monotone_append`, `theorem2_budget_step`, `theorem2_example_profile`, `theorem2_budget_guard` | `test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget`, `test/rdp_accountant_test.go::TestRDPAccountant_CheckBudget_Exceeded` | Surrogate verified | Current Lean scope is list-based `Nat` composition and budget guards; full RDP and `(ε, δ)` conversion remain roadmap work |
| 3 | Hierarchical routing has logarithmic per-update path depth proxy O(d log n); total bytes remain model-dependent | [proofs/communication.md](communication.md) | `LeanFormalization/Theorem3Communication.lean` | `theorem3_hierarchical_additivity`, `theorem3_large_scale_check`, `theorem3_hierarchical_scale_check`, `theorem3_lower_bound_match`, `theorem3_one_message_per_level` | `test/manifest_test.go::TestValidateCommunicationComplexity_Valid`, `test/manifest_test.go::TestValidateCommunicationComplexity_Violated` | Verified | Path-depth logarithmic bound is formalized; a separate compression theorem is needed for sublinear total-byte claims |
| 4 | Integer redundancy/dropout surrogate exceeds configured liveness guards for concrete profiles | [internal/stragglers.md](../internal/stragglers.md) | `LeanFormalization/Theorem4Liveness.lean` | `theorem4_redundancy_monotone`, `theorem4_success_gt_99_9`, `theorem4_success_gt_99_8`, `theorem4_success_gt_99_9_r12` | `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass`, `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Fail` | Surrogate verified | Integer dropout surrogate model only; probability-measure and Chernoff formalization remain planned work |
| 5 | Constant proof-size and verifier-cost model is scale-invariant | [proofs/cryptography.md](cryptography.md) | `LeanFormalization/Theorem5Cryptography.lean` | `theorem5_constant_size`, `theorem5_constant_ops`, `theorem5_constant_cost`, `theorem5_ops_guard`, `theorem5_cost_guard` | `test/zk_verifier_test.go::TestVerifyZKProof`, `test/zksnark_verifier_test.go::TestVerifyProof_Valid` | Model verified | Abstract constant-operation verifier model with concrete runtime guard; not a full Groth16/q-SDH formalization |
| 6 | Surrogate convergence envelope decreases with rounds and grows with heterogeneity | [proofs/convergence.md](convergence.md) | `LeanFormalization/Theorem6Convergence.lean` | `theorem6_envelope_decompose`, `theorem6_rounds_help`, `theorem6_rounds_help_stronger`, `theorem6_heterogeneity_effect`, `theorem6_large_scale_guard` | `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` | Surrogate verified | Current Lean files cover integer and rational envelope models; the stronger non-convex `O(1/sqrt(KT))` claim is not yet formally established here |
| 7 | Flower-compatible client training preserves Mohawk compression, proof-envelope generation, and Go-backed aggregation | [docs/flower-integration.md](../docs/flower-integration.md) | `LeanFormalization/Theorem1BFT.lean`, `LeanFormalization/Theorem3Communication.lean`, `LeanFormalization/Theorem5Cryptography.lean`, `LeanFormalization/Theorem6Convergence.lean` | `theorem1_global_bound_checked`, `theorem3_lower_bound_match`, `theorem5_constant_cost`, `theorem6_large_scale_guard` | `sdk/python/tests/test_flower_client.py::test_fit_submits_update_and_builds_proof_manifest`, `sdk/python/tests/test_flower_strategy.py::test_strategy_forwarder_aggregates_updates`, `sdk/python/tests/test_flower_examples.py::test_all_flower_integrated_examples`, `sdk/python/examples/flower_integrated/quickstart_pytorch.py::main` | Verified | Flower client and strategy bridge reuse theorem-backed runtime semantics |
| 8 | PQC migration continuity requires dual signatures across cutover phases | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem7PQCMigrationContinuity.lean` | `theorem7_dual_signature_continuity`, `theorem7_legacy_compromise_insufficient`, `theorem7_post_epoch_soundness`, `theorem7_scale_guard`, `theorem7_pqc_hardness_ensures_continuity` | `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath`, `test/utility_coin_test.go::TestUtilityCoinDualSignatureMigrationCryptographic` | Verified | Adds phase-aware migration model and 10M-scale acceptance guard |
| 9 | Legacy-only migration cannot satisfy post-cutover non-hijack policy | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem8DualSignatureNonHijack.lean` | `theorem8_post_epoch_non_hijack`, `theorem8_no_pqc_not_safe`, `theorem8_scale_non_hijack_guard`, `theorem8_pqc_prevents_hijack` | `test/utility_coin_settlement_test.go::TestUtilityCoinTaskSettlementRequiresValidProof`, `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath` | Verified | Connects non-hijack theorem to runtime payout and migration guards |

## Parser Compatibility

This matrix is designed for automated extraction:
- **Lean module pattern**: `LeanFormalization/Theorem[0-9]+\.lean`
- **Runtime test pattern**: `[^ ]+\.(go|py)::[A-Za-z0-9_]+`
- **All entries single-line** to support grep/regex tooling
- **No markdown links in cells** for clean parser operation

## Phase 2 Completion Notes

- Theorem 1 and 2 were deepened from profile-only checks to reusable compositional lemmas.
- Theorems 3-6 now include stronger structural properties beyond single-point checks.
- CI now enforces placeholder-free formal modules (`sorry`, `axiom`, `admit` forbidden) and proof build success.

## Machine-Checkable Validation Artifacts

- Canonical report: `results/proofs/formal_validation_report.json`
- Bundle manifest: `results/proofs/formal-verification-bundle/bundle_manifest.json`
- Bundle archive: `results/proofs/formal-verification-bundle.tar.gz`
- Regenerate artifacts: `make refresh-formal-validation`
- Validate report and bundle integrity: `make validate-formal`

