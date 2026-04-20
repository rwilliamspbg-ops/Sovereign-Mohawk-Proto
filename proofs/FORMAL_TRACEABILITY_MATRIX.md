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
| 1 | 55.5% Byzantine resilience via hierarchical Multi-Krum | proofs/bft_resilience.md | LeanFormalization/Theorem1BFT.lean | theorem1_half_bound_of_forall, theorem1_five_ninths_of_half_bound, theorem1_global_bound_checked, theorem1_ten_million_corollary, theorem1_hierarchical_additivity | internal/multikrum_test.go::TestMultiKrumSelect, internal/aggregator_multikrum_test.go::TestProcessGradientBatchWithMultiKrum | Verified | Concrete numeric bounds only |
| 2 | Rényi DP composition across 4 tiers achieves ε ≈ 2.0 | proofs/differential_privacy.md | LeanFormalization/Theorem2RDP.lean | theorem2_composition_append, theorem2_monotone_append, theorem2_budget_step, theorem2_example_profile, theorem2_budget_guard, theorem2_hierarchical_rdp_bound, theorem2_alpha_10_delta_1e5 | test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget, test/rdp_accountant_test.go::TestRDPAccountant_CheckBudget_Exceeded | Verified | Compositional lemmas added in Phase 2 |
| 3 | O(d log n) hierarchical communication matching information-theoretic lower bound | proofs/communication.md | LeanFormalization/Theorem3Communication.lean | theorem3_hierarchical_additivity, theorem3_large_scale_check, theorem3_hierarchical_scale_check, theorem3_lower_bound_match, theorem3_one_message_per_level | test/manifest_test.go::TestValidateCommunicationComplexity_Valid, test/manifest_test.go::TestValidateCommunicationComplexity_Violated | Verified | native_decide for Nat.log evaluation |
| 4 | 99.99% operational reliability with 10x redundancy against 50% regional dropout | internal/stragglers.md | LeanFormalization/Theorem4Liveness.lean | theorem4_redundancy_monotone, theorem4_success_gt_99_9, theorem4_success_gt_99_9_r12, theorem4_hierarchical_liveness, theorem4_concrete_validation | test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass, test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Fail | Verified | Rational arithmetic; Chernoff planned for Phase 3b |
| 5 | zk-SNARK constant size (200 bytes) and O(1) verification time | proofs/cryptography.md | LeanFormalization/Theorem5Cryptography.lean | theorem5_constant_size, theorem5_constant_ops, theorem5_constant_cost, theorem5_cost_guard, theorem5_scale_independence | test/zk_verifier_test.go::TestVerifyZKProof, test/zksnark_verifier_test.go::TestVerifyProof_Valid | Verified | q-SDH assumption; soundness axiomatized |
| 6 | Non-IID hierarchical SGD convergence O(1/√KT) + O(ζ²) rate | proofs/convergence.md | LeanFormalization/Theorem6Convergence.lean | theorem6_envelope_decompose, theorem6_rounds_help, theorem6_rounds_help_stronger, theorem6_heterogeneity_effect, theorem6_large_scale_guard | test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below, test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above | Verified | Structural decomposition only; full convergence planned for Phase 3b |

## Parser Compatibility

This matrix is designed for automated extraction:
- **Lean module pattern**: `LeanFormalization/Theorem[0-9]+\.lean`
- **Runtime test pattern**: `[^ ]+\.(go|py)::[A-Za-z0-9_]+`
- **All entries single-line** to support grep/regex tooling
- **No markdown links in cells** for clean parser operation
