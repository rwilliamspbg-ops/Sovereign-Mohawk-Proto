# Formal Proof Traceability Matrix

This matrix maps repository theorem claims to machine-checked Lean modules and theorem names.

## Scope

- Lean project root: `proofs/`
- Main import entry: `proofs/LeanFormalization.lean`
- Build command: `cd proofs && lake build LeanFormalization Mathlib`

## Mapping

| Claim Source | Lean Module | Key Machine-Checked Theorems | Runtime Test Evidence |
| --- | --- | --- | --- |
| `proofs/bft_resilience.md` (Theorem 1) | `LeanFormalization/Theorem1BFT.lean` | `theorem1_half_bound_of_forall`, `theorem1_five_ninths_of_half_bound`, `theorem1_global_bound_checked`, `theorem1_ten_million_corollary` | `internal/multikrum_test.go::TestMultiKrumSelect`, `internal/aggregator_multikrum_test.go::TestProcessGradientBatchWithMultiKrum` |
| `proofs/differential_privacy.md` (Theorem 2) | `LeanFormalization/Theorem2RDP.lean` | `theorem2_composition_append`, `theorem2_monotone_append`, `theorem2_budget_step`, `theorem2_example_profile`, `theorem2_budget_guard` | `test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget`, `test/rdp_accountant_test.go::TestRDPAccountant_CheckBudget_Exceeded` |
| `proofs/communication.md` (Theorem 3) | `LeanFormalization/Theorem3Communication.lean` | `theorem3_hierarchical_additivity`, `theorem3_large_scale_check`, `theorem3_hierarchical_scale_check` | `test/manifest_test.go::TestValidateCommunicationComplexity_Valid`, `test/manifest_test.go::TestValidateCommunicationComplexity_Violated` |
| `internal/stragglers.md` (Theorem 4) | `LeanFormalization/Theorem4Liveness.lean` | `theorem4_redundancy_monotone`, `theorem4_success_gt_99_9`, `theorem4_success_gt_99_9_r12` | `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass`, `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Fail` |
| `proofs/cryptography.md` (Theorem 5) | `LeanFormalization/Theorem5Cryptography.lean` | `theorem5_constant_size`, `theorem5_constant_ops`, `theorem5_constant_cost`, `theorem5_cost_guard` | `test/zk_verifier_test.go::TestVerifyZKProof`, `test/zksnark_verifier_test.go::TestVerifyProof_Valid` |
| `proofs/convergence.md` (Theorem 6) | `LeanFormalization/Theorem6Convergence.lean` | `theorem6_envelope_decompose`, `theorem6_rounds_help`, `theorem6_rounds_help_stronger`, `theorem6_heterogeneity_effect` | `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` |

## Phase 2 Completion Notes

- Theorem 1 and 2 were deepened from profile-only checks to reusable compositional lemmas.
- Theorems 3-6 now include stronger structural properties beyond single-point checks.
- CI now enforces placeholder-free formal modules (`sorry`, `axiom`, `admit` forbidden) and proof build success.
