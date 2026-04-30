# Formal Proof Traceability Matrix

Authoritative cross-reference between theorem claims, human-readable proofs, machine-checked Lean 4 modules, and runtime test evidence.

> **Phase 4 Note**: Migration theorems now include a UF-CMA adversary game, explicit ledger transition rules, preserved invariants, and closed refinement lemmas toward Go runtime checks.

## Scope

- Lean project root: `proofs/`
- Main import entry: `proofs/LeanFormalization.lean`
- Build command: `cd proofs && lake build LeanFormalization`

## Mapping

| # | Claim (Short) | Claim Source | Lean Module | Key Machine-Checked Theorems | Runtime Test Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 55.5% Byzantine resilience via hierarchical Multi-Krum at 10M node scale | [proofs/bft_resilience.md](bft_resilience.md) | `LeanFormalization/Theorem1BFT.lean` | `theorem1_half_bound_of_forall_cons`, `theorem1_half_bound_of_forall`, `theorem1_five_ninths_of_half_bound`, `theorem1_tier_majority_checked`, `theorem1_global_bound_checked`, `theorem1_ten_million_corollary` | `internal/multikrum_test.go::TestMultiKrumSelect`, `internal/aggregator_multikrum_test.go::TestProcessGradientBatchWithMultiKrum` | fully_formalized | Concrete numeric bounds; deterministic model only |
| 2 | Integer composition surrogate for a 4-tier privacy-budget profile (with Gaussian RDP axiom bridge) | [proofs/differential_privacy.md](differential_privacy.md) | `LeanFormalization/Theorem2RDP.lean` | `theorem2_composition_append`, `theorem2_monotone_append`, `theorem2_budget_step`, `theorem2_example_profile`, `theorem2_budget_guard` | `test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget`, `test/rdp_accountant_test.go::TestRDPAccountant_CheckBudget_Exceeded` | surrogate_verified_with_gaussian_axiom | Current Lean scope is list-based `Nat` composition and budget guards; Gaussian mechanism bounds abstracted via axiom; full RDP and `(ε, δ)` conversion remain roadmap work |
| 3 | Hierarchical routing has logarithmic per-update path depth proxy O(d log n); total bytes remain model-dependent | [proofs/communication.md](communication.md) | `LeanFormalization/Theorem3Communication.lean` | `theorem3_hierarchical_additivity`, `theorem3_large_scale_check`, `theorem3_hierarchical_scale_check`, `theorem3_lower_bound_match`, `theorem3_one_message_per_level` | `test/manifest_test.go::TestValidateCommunicationComplexity_Valid`, `test/manifest_test.go::TestValidateCommunicationComplexity_Violated` | fully_formalized | Path-depth logarithmic bound is formalized; a separate compression theorem is needed for sublinear total-byte claims |
| 4 | Integer redundancy/dropout surrogate exceeds configured liveness guards for concrete profiles | [internal/stragglers.md](../internal/stragglers.md) | `LeanFormalization/Theorem4Liveness.lean` | `theorem4_redundancy_monotone`, `theorem4_success_gt_99_9`, `theorem4_success_gt_99_8`, `theorem4_success_gt_99_9_r12` | `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass`, `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Fail` | model_verified | Integer dropout surrogate model; Chernoff-style extension provides probabilistic bounds; probability-measure and full stochastic formalization remain planned work |
| 5 | Constant proof-size and verifier-cost model is scale-invariant | [proofs/cryptography.md](cryptography.md) | `LeanFormalization/Theorem5Cryptography.lean` | `theorem5_constant_size`, `theorem5_constant_ops`, `theorem5_constant_cost`, `theorem5_ops_guard`, `theorem5_cost_guard` | `test/zk_verifier_test.go::TestVerifyZKProof`, `test/zksnark_verifier_test.go::TestVerifyProof_Valid` | model_verified | Abstract constant-operation verifier model with concrete runtime guard; not a full Groth16/q-SDH formalization |
| 6 | Surrogate convergence envelope decreases with rounds and grows with heterogeneity (with real-valued bridge) | [proofs/convergence.md](convergence.md) | `LeanFormalization/Theorem6Convergence.lean` | `theorem6_envelope_decompose`, `theorem6_rounds_help`, `theorem6_rounds_help_stronger`, `theorem6_heterogeneity_effect`, `theorem6_large_scale_guard` | `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` | surrogate_verified_with_cast_bridge | Current Lean covers integer and rational envelope models refactored to real values; stronger non-convex `O(1/sqrt(KT))` bounds remain as planned roadmap work |
| 7 | Flower-compatible client training preserves Mohawk compression, proof-envelope generation, and Go-backed aggregation | [docs/flower-integration.md](../docs/flower-integration.md) | `LeanFormalization/Theorem1BFT.lean`, `LeanFormalization/Theorem3Communication.lean`, `LeanFormalization/Theorem5Cryptography.lean`, `LeanFormalization/Theorem6Convergence.lean` | `theorem1_global_bound_checked`, `theorem3_lower_bound_match`, `theorem5_constant_cost`, `theorem6_large_scale_guard` | `sdk/python/tests/test_flower_client.py::test_fit_submits_update_and_builds_proof_manifest`, `sdk/python/tests/test_flower_strategy.py::test_strategy_forwarder_aggregates_updates`, `sdk/python/tests/test_flower_examples.py::test_all_flower_integrated_examples`, `sdk/python/examples/flower_integrated/quickstart_pytorch.py::main` | Verified | Flower client and strategy bridge reuse theorem-backed runtime semantics |
| 8 | PQC migration continuity requires dual signatures across cutover phases | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem7PQCMigrationContinuity.lean` | `theorem7_dual_signature_continuity`, `theorem7_legacy_compromise_insufficient`, `theorem7_pqc_hardness_ensures_continuity`, `theorem7_scale_guard`, `theorem7_refines_go_migration`, `theorem7_refines_go_field_mapping` | `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath`, `test/utility_coin_test.go::TestUtilityCoinDualSignatureMigrationCryptographic` | Phase 4 model | Traceability target: `dualSignatureVerify` in migration_signatures.go and post-epoch acceptance checks in settlement.go |
| 9 | Legacy-only migration cannot satisfy post-cutover non-hijack policy | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem8DualSignatureNonHijack.lean` | `LedgerTransition`, `ledger_invariant_post_epoch`, `theorem8_post_epoch_non_hijack`, `theorem8_no_pqc_not_safe`, `theorem8_pqc_prevents_hijack`, `theorem8_no_hijack_possible`, `theorem8_scale_non_hijack_guard`, `theorem8_refines_go_settlement` | `test/utility_coin_settlement_test.go::TestUtilityCoinTaskSettlementRequiresValidProof`, `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath` | Phase 4 model | Includes linkage to dual-signature checks plus compute-proof-gated settlement path |
| 10 | Chernoff-style probabilistic liveness extension closes the failure-probability gap | [internal/stragglers.md](../internal/stragglers.md) | `LeanFormalization/Theorem4ChernoffBounds.lean` | `chernoff_bound`, `chernoff_monotone`, `chernoff_alpha_09_r12`, `failure_implies_success`, `theorem4_chernoff_bounds`, `chernoff_redundancy_effectiveness`, `chernoff_hierarchical_composition`, `theorem4_hierarchical_chernoff_validation`, `theorem4_union_bound`, `theorem4_full_independence_model` | `test/phase3b_theorems_test.go::TestChernoffBound_Basic`, `test/phase3b_theorems_test.go::TestChernoffBound_Monotonicity`, `test/phase3b_theorems_test.go::TestChernoffBound_Effectiveness`, `test/phase3b_theorems_test.go::TestChernoffBound_HierarchicalComposition` | Phase 3b model | Extends the liveness surrogate with a probabilistic redundancy bound and concrete success thresholds |
| 11 | Real-valued convergence envelope preserves the runtime guard while refining the proof model | [proofs/convergence.md](convergence.md) | `LeanFormalization/Theorem6ConvergenceReals.lean` | `convergence_envelope_decompose`, `convergence_rounds_help_numeric`, `convergence_rounds_help_strong`, `convergence_envelope_concrete_100_1000`, `convergence_heterogeneity_effect`, `convergence_envelope_momentum`, `theorem6_hierarchical_convergence_rate`, `convergence_dimension_independent`, `convergence_preserves_hierarchical_communication`, `convergence_with_strong_convexity`, `theorem6_variance_reduction_convergence`, `theorem6_hierarchical_convergence_holds`, `theorem6_exact_convergence_regime`, `theorem6_non_convex_lower_bound`, `convergence_large_scale_envelope` | `test/phase3b_theorems_test.go::TestConvergenceEnvelope_Concrete`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_RoundsHelp`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_HeterogeneityEffect`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_DimensionIndependent`, `test/phase3b_theorems_test.go::TestConvergenceStrongConvexity`, `test/phase3b_theorems_test.go::TestConvergenceVarianceReduction`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` | Surrogate verified | Refines the convergence claim toward the real-valued Phase 3b model while preserving runtime guard alignment |

## Workstream 4: PQC Migration Hardening (Phase 4)

| Theorem ID | Formal Statement | Key Properties Proven | Linked Go Implementation | Upgrade Plan Reference | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Theorem7 | `PQCMigrationContinuity` | Dual-signature continuity, legacy compromise insufficiency, PQC hardness under UF-CMA | `internal/token/migration_signatures.go::verifyMigrationSignatureBundle`, `internal/token/settlement.go` post-epoch acceptance path | Workstream 4 (2026-2027) | Complete (Phase 4) | Includes `goVerifyMigrationSignatureBundle` and `goPostEpochAccept` refinement shims in Lean |
| Theorem8 | `DualSignatureNonHijack` | Non-hijack safety, `LedgerTransition` invariant preservation, no-hijack under UF-CMA | `internal/token/settlement.go` payout path, plus migration-signature enforcement in `internal/token/migration_signatures.go` | Workstream 4 (2026-2027) | Complete (Phase 4) | Includes `goSettleTaskPayoutSafe` refinement shim tying valid-proof gate to Lean safety predicate |

### Shared Supporting Definitions

- `ufCmaWins`, `pqcUnforgeable`, `MigrationAuth`, `MigrationPhase`, `LedgerState`, `postEpochAccepts`, `hijackSafe`: centralized in `LeanFormalization/Common.lean`
- `LedgerTransition`: theorem-specific transition relation in `LeanFormalization/Theorem8DualSignatureNonHijack.lean`

## Parser Compatibility

This matrix is designed for automated extraction:
- **Lean module pattern**: `LeanFormalization/Theorem[0-9]+\.lean`
- **Runtime test pattern**: `[^ ]+\.(go|py)::[A-Za-z0-9_]+`
- **All entries single-line** to support grep/regex tooling
- **No markdown links in cells** for clean parser operation

## Phase 4 Completion Notes

- Theorems 7 and 8 now model UF-CMA with chosen-message queries and fresh-message forgery conditions.
- Migration security is encoded through `LedgerTransition` with explicit invariant preservation.
- Refinement lemmas are closed (no placeholders) and document mapping to Go migration and settlement checks.

## Machine-Checkable Validation Artifacts

- Canonical report: `results/proofs/formal_validation_report.json`
- Bundle manifest: `results/proofs/formal-verification-bundle/bundle_manifest.json`
- Bundle archive: `results/proofs/formal-verification-bundle.tar.gz`
- Regenerate artifacts: `make refresh-formal-validation`
- Validate report and bundle integrity: `make validate-formal`

## Latest Validation Run

- Date (UTC): 2026-04-26
- Branch: `feat/planning-doc-and-validation-scripts`
- Commands executed:
  - `cd proofs && /home/codespace/.elan/bin/lake build`
  - `bash scripts/ci/validate_formal_traceability.sh`
  - `/workspaces/Sovereign-Mohawk-Proto/.venv/bin/python scripts/ci/generate_formal_validation_report.py`
  - `/workspaces/Sovereign-Mohawk-Proto/.venv/bin/python scripts/ci/generate_formal_validation_report.py --check`
- Results:
  - Lean build: pass
  - Traceability validation: pass (`8` modules, `48` theorem symbols, `20` runtime test refs)
  - Formal validation report consistency: pass after regeneration
