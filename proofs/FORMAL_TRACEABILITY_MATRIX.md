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
| 1 | 55.5% Byzantine resilience via hierarchical Multi-Krum at 10M node scale | [proofs/bft_resilience.md](bft_resilience.md) | `LeanFormalization/Theorem1BFT.lean` | `theorem1_half_bound_of_forall_cons`, `theorem1_half_bound_of_forall`, `theorem1_five_ninths_of_half_bound`, `theorem1_tier_majority_checked`, `theorem1_global_bound_checked`, `theorem1_ten_million_corollary`, `hierarchical_composition_counterexample` | `internal/multikrum_test.go::TestMultiKrumSelect`, `internal/aggregator_multikrum_test.go::TestProcessGradientBatchWithMultiKrum` | fully_formalized (single-tier); compositional claim disproven | Every listed single-tier theorem derives its conclusion from a stated hypothesis (the 5/9 profile guard `9f < 5n`, or the honest-majority guard `2f < n`) rather than proving an unconditional `True`/existential — a prior revision's `theorem1_hierarchical_bft_tolerance` picked `f_global ≥ 555/1000` as a witness regardless of any input and proved nothing. This is still a guard-dependent arithmetic fact for a *given* tier configuration, not a proof that recursive hierarchical composition of per-tier honest-majority filtering converges to 55.5% (or any fixed fraction) in general. **That compositional question was attempted for real this pass and found FALSE**: `hierarchical_composition_counterexample` is a machine-checked, concrete 2-child tree where a weighted (by actual subtree leaf-count) local honest-majority guard holds at every level, yet the true global Byzantine leaf fraction is 60%. Reworking the algebra for any fixed per-level threshold reproduces the same gap — structural, not a tuning problem. A true compositional claim needs a probabilistic argument (random committee sampling + a concentration bound), matching this system's actual architecture, not attempted here — see `Theorem1BFT.lean`'s own comment and `bft_resilience.md`'s "Correction" section for the full argument. |
| 2 | Integer composition surrogate for a 4-tier privacy-budget profile (with Gaussian RDP axiom bridge) | [proofs/differential_privacy.md](differential_privacy.md) | `LeanFormalization/Theorem2RDP.lean` | `theorem2_composition_append`, `theorem2_monotone_append`, `theorem2_budget_step`, `theorem2_example_profile`, `theorem2_budget_guard` | `test/rdp_accountant_test.go::TestRDPAccountant_InitialBudget`, `test/rdp_accountant_test.go::TestRDPAccountant_CheckBudget_Exceeded` | surrogate_verified_with_gaussian_axiom | Current Lean scope is list-based `Nat` composition and budget guards; Gaussian mechanism bounds abstracted via axiom; full RDP and `(ε, δ)` conversion remain roadmap work. Separately, `RenyiDivergence_nonneg` (with added normalization hypotheses `∑p=1`,`∑q=1` — without them the claim is false) and `data_processing_inequality` (order > 1 case) in the same file are now real, checked proofs via the weighted power-mean inequality, not part of this row's cited claim surface but no longer `True`-stub placeholders either. Of the three `sorry`s previously open in this file, two are now closed: `RenyiDivergence_limit_KL` — the version left `sorry`'d previously stated the wrong limit (`∑p·log(p/q)`; the file's own convention actually limits to `∑q·log(q/p)` as order→1⁺, a real bug independent of proof difficulty, found and fixed here) and is now a genuine `hasDerivAt_iff_tendsto_slope` proof; `data_processing_inequality_KL` is now proven for surjective `f` by taking the order→1⁺ limit of the already-proven `data_processing_inequality` on both sides via `RenyiDivergence_limit_KL`, rather than a fresh log-sum-inequality argument. `RDP_sequential_composition` remains open, and should — its current statement compares Rényi divergence between a *deterministic* function's different output-fiber indicators rather than a randomized mechanism's outputs on adjacent databases; a new lemma `RDP_indicator_divergence_disjoint_eq_zero` (machine-checked) proves this makes the statement **vacuously true regardless of M1/M2's structure** (the hypotheses are always satisfiable with `eps1=eps2=0` for any M1, M2), so closing this `sorry` as currently stated would add a tautology, not a composition theorem. It needs a full restatement with actual randomized mechanisms and the joint/conditional Rényi chain rule, not a proof of what's there — see the theorem's own doc comment for the complete argument. (The previously-removed `Theorem2RDP_ChainRule.lean` attempted the chain-rule route and did not compile; there is nothing usable to build on there.) |
| 3 | Hierarchical routing has logarithmic per-update path depth proxy O(d log n); total bytes remain model-dependent | [proofs/communication.md](communication.md) | `LeanFormalization/Theorem3Communication.lean` | `theorem3_hierarchical_additivity`, `theorem3_large_scale_check`, `theorem3_hierarchical_scale_check`, `theorem3_lower_bound_match`, `theorem3_one_message_per_level` | `test/manifest_test.go::TestValidateCommunicationComplexity_Valid`, `test/manifest_test.go::TestValidateCommunicationComplexity_Violated` | fully_formalized | Path-depth logarithmic bound is formalized; a separate compression theorem is needed for sublinear total-byte claims. `theorem3_hierarchical_scale_check`, `theorem3_lower_bound_match`, and `theorem3_one_message_per_level` were `True`-stub placeholders (found via `scripts/ci/lint_formal_proof_claims.py`, which is real but was not wired into any CI workflow or Makefile target) that proved nothing about their namesakes; now real, checked theorems. |
| 4 | Redundancy/dropout surrogate exceeds configured liveness guards for concrete profiles | [internal/stragglers.md](../internal/stragglers.md) | `LeanFormalization/Theorem4Liveness.lean` | `theorem4_redundancy_monotone`, `theorem4_success_gt_99_9`, `theorem4_success_gt_99_8`, `theorem4_success_gt_99_9_r12` | `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Pass`, `test/straggler_test.go::TestStragglerMonitor_ValidateLiveness_Fail` | model_verified | Rebuilt on the Chernoff-bound model from `Theorem4ChernoffBounds.lean` (`chernoff_bound alpha r = (1-alpha)^r`, `chernoff_monotone`). A prior revision proved these four names against a bare `True` goal — including a "Main service availability theorem" that computed `global_service` via a `let` and then never referenced it in the goal (Lean's own unused-variable linter flagged this). Each now concludes an inequality on the actual availability quantity for a stated redundancy level (r=4/8/12 at 90% per-replica availability); probability-measure and full stochastic formalization remain planned work. |
| 5 | Constant proof-size and verifier-cost model is scale-invariant | [proofs/cryptography.md](cryptography.md) | `LeanFormalization/Theorem5Cryptography.lean` | `theorem5_constant_size`, `theorem5_constant_ops`, `theorem5_constant_cost`, `theorem5_ops_guard`, `theorem5_cost_guard` | `test/zk_verifier_test.go::TestVerifyHashCommitment`, `test/zksnark_verifier_test.go::TestVerifyProof_Valid` | model_verified | Abstract constant-operation verifier model with concrete runtime guard; not a full Groth16/q-SDH formalization |
| 6 | Surrogate convergence envelope decreases with rounds and grows with heterogeneity (with real-valued bridge) | [proofs/convergence.md](convergence.md) | `LeanFormalization/Theorem6Convergence.lean` | `theorem6_envelope_decompose`, `theorem6_rounds_help`, `theorem6_rounds_help_stronger`, `theorem6_heterogeneity_effect`, `theorem6_large_scale_guard` | `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` | surrogate_verified_with_cast_bridge | Current Lean covers integer and rational envelope models refactored to real values; stronger non-convex `O(1/sqrt(KT))` bounds remain as planned roadmap work |
| 7 | Flower-compatible client training preserves Mohawk compression, proof-envelope generation, and Go-backed aggregation | [docs/flower-integration.md](../docs/flower-integration.md) | `LeanFormalization/Theorem1BFT.lean`, `LeanFormalization/Theorem3Communication.lean`, `LeanFormalization/Theorem5Cryptography.lean`, `LeanFormalization/Theorem6Convergence.lean` | `theorem1_global_bound_checked`, `theorem3_lower_bound_match`, `theorem5_constant_cost`, `theorem6_large_scale_guard` | `sdk/python/tests/test_flower_client.py::test_fit_submits_update_and_builds_proof_manifest`, `sdk/python/tests/test_flower_strategy.py::test_strategy_forwarder_aggregates_updates`, `sdk/python/tests/test_flower_examples.py::test_all_flower_integrated_examples`, `sdk/python/examples/flower_integrated/quickstart_pytorch.py::main` | Verified | Flower client and strategy bridge reuse theorem-backed runtime semantics |
| 8 | PQC migration continuity requires dual signatures across cutover phases | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem7PQCMigrationContinuity.lean` | `theorem7_dual_signature_continuity`, `theorem7_legacy_compromise_insufficient`, `theorem7_pqc_hardness_ensures_continuity`, `theorem7_scale_guard`, `theorem7_refines_go_migration`, `theorem7_refines_go_field_mapping` | `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath`, `test/utility_coin_test.go::TestUtilityCoinDualSignatureMigrationCryptographic` | Phase 4 model | Traceability target: `dualSignatureVerify` in migration_signatures.go and post-epoch acceptance checks in settlement.go. **Caveat on `theorem7_legacy_compromise_insufficient` and `theorem7_pqc_hardness_ensures_continuity`**: these are NOT PQC-hardness security reductions despite their names — `postEpochAccepts auth := auth.legacySigned ∧ auth.pqcSigned` is a plain structural conjunction with no link to `PQCSig`/`Adversary`/`ufCmaWins`, so both conclusions follow from `postEpochAccepts` alone; the `legacyCompromised`/`pqcUnforgeable` hypotheses are accepted but unused. A genuine reduction needs `auth.pqcSigned` derived from an actual `PQCSig.verify` call over adversary-controlled input — not yet modeled. See the in-file comment above these theorems. |
| 9 | Legacy-only migration cannot satisfy post-cutover non-hijack policy | [internal/token/migration_signatures.go](../internal/token/migration_signatures.go), [internal/token/settlement.go](../internal/token/settlement.go) | `LeanFormalization/Theorem8DualSignatureNonHijack.lean` | `LedgerTransition`, `ledger_invariant_post_epoch`, `theorem8_post_epoch_non_hijack`, `theorem8_no_pqc_not_safe`, `theorem8_pqc_prevents_hijack`, `theorem8_no_hijack_possible`, `theorem8_scale_non_hijack_guard`, `theorem8_refines_go_settlement` | `test/utility_coin_settlement_test.go::TestUtilityCoinTaskSettlementRequiresValidProof`, `test/utility_coin_test.go::TestUtilityCoinMigrationEpochEnforcesCryptographicPath` | Phase 4 model | Includes linkage to dual-signature checks plus compute-proof-gated settlement path. **Caveat on `theorem8_pqc_prevents_hijack`**: same as Theorem7's caveat above — `hijackSafe auth := auth.pqcSigned` is a plain projection, so this is not yet a PQC-hardness security reduction; the `pqcUnforgeable` hypothesis is accepted but unused. |
| 10 | Chernoff-style probabilistic liveness extension closes the failure-probability gap | [internal/stragglers.md](../internal/stragglers.md) | `LeanFormalization/Theorem4ChernoffBounds.lean` | `chernoff_bound`, `chernoff_monotone`, `chernoff_alpha_09_r12`, `failure_implies_success`, `theorem4_chernoff_bounds`, `chernoff_redundancy_effectiveness`, `chernoff_hierarchical_composition`, `theorem4_hierarchical_chernoff_validation`, `theorem4_union_bound`, `theorem4_full_independence_model` | `test/phase3b_theorems_test.go::TestChernoffBound_Basic`, `test/phase3b_theorems_test.go::TestChernoffBound_Monotonicity`, `test/phase3b_theorems_test.go::TestChernoffBound_Effectiveness`, `test/phase3b_theorems_test.go::TestChernoffBound_HierarchicalComposition` | Phase 3b model | Extends the liveness surrogate with a probabilistic redundancy bound and concrete success thresholds |
| 11 | Real-valued convergence envelope preserves the runtime guard while refining the proof model | [proofs/convergence.md](convergence.md) | `LeanFormalization/Theorem6ConvergenceReals.lean` | `convergence_envelope_decompose`, `convergence_rounds_help_numeric`, `convergence_rounds_help_strong`, `convergence_envelope_concrete_100_1000`, `convergence_heterogeneity_effect`, `convergence_envelope_momentum`, `theorem6_hierarchical_convergence_rate`, `convergence_dimension_independent`, `convergence_preserves_hierarchical_communication`, `convergence_with_strong_convexity`, `theorem6_variance_reduction_convergence`, `theorem6_hierarchical_convergence_holds`, `theorem6_exact_convergence_regime`, `theorem6_non_convex_lower_bound`, `convergence_large_scale_envelope` | `test/phase3b_theorems_test.go::TestConvergenceEnvelope_Concrete`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_RoundsHelp`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_HeterogeneityEffect`, `test/phase3b_theorems_test.go::TestConvergenceEnvelope_DimensionIndependent`, `test/phase3b_theorems_test.go::TestConvergenceStrongConvexity`, `test/phase3b_theorems_test.go::TestConvergenceVarianceReduction`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Below`, `test/convergence_test.go::TestConvergenceMonitor_IsConverging_Above` | Surrogate verified | Refines the convergence claim toward the real-valued Phase 3b model while preserving runtime guard alignment |

## Workstream 4: PQC Migration Hardening (Phase 4)

| Theorem ID | Formal Statement | Key Properties Proven | Linked Go Implementation | Upgrade Plan Reference | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Theorem7 | `PQCMigrationContinuity` | Dual-signature continuity, legacy compromise insufficiency; **"PQC hardness under UF-CMA" is not actually proven** (see row 8 caveat above) | `internal/token/migration_signatures.go::verifyMigrationSignatureBundle`, `internal/token/settlement.go` post-epoch acceptance path | Workstream 4 (2026-2027) | Complete (Phase 4) | Includes `goVerifyMigrationSignatureBundle` and `goPostEpochAccept` refinement shims in Lean |
| Theorem8 | `DualSignatureNonHijack` | Non-hijack safety, `LedgerTransition` invariant preservation; **"no-hijack under UF-CMA" is not actually proven** (see row 9 caveat above) | `internal/token/settlement.go` payout path, plus migration-signature enforcement in `internal/token/migration_signatures.go` | Workstream 4 (2026-2027) | Complete (Phase 4) | Includes `goSettleTaskPayoutSafe` refinement shim tying valid-proof gate to Lean safety predicate |

### Shared Supporting Definitions

- `ufCmaWins`, `pqcUnforgeable`, `MigrationAuth`, `MigrationPhase`, `LedgerState`, `postEpochAccepts`, `hijackSafe`: centralized in `LeanFormalization/Common.lean`
- `LedgerTransition`: theorem-specific transition relation in `LeanFormalization/Theorem8DualSignatureNonHijack.lean`

## Quarantined Modules

Two files previously lived under `proofs/LeanFormalization/` — not imported
by `LeanFormalization.lean`, never listed in this matrix, never referenced
by a public claim — but were still compiled by `lake build LeanFormalization`
(Lake's default `lean_lib` glob covers every `.lean` file under the
directory regardless of the import graph), so they sat in the checked build
tree looking like verified artifacts despite never being part of the actual
claim surface. Moved to `proofs/quarantined/` (outside every `lean_lib`
target in `proofs/lakefile.lean`, so no longer built at all) during a
Phase 0 claim-hygiene pass:

- **`Theorem2RDP_GaussianRDP.lean`** — `gaussian_RDP_bound` compares
  `RenyiDivergence` between two identical constant functions, not real
  Gaussian likelihoods (`GaussianMechanism` is literally the identity
  function per its own comment), so it establishes nothing about actual
  Gaussian mechanisms regardless of whether it type-checks.
- **`Theorem2RDP_MomentAccountant.lean`** — `moment_rdp_equivalence`
  concludes bare `True` (proved `by trivial`), the same vacuous-conclusion
  pattern this matrix's Theorem 3 row documents `lint_formal_proof_claims.py`
  catching elsewhere.

Both are relevant to closing Theorem 2's open `sorry`s (row 2 above) as
future work, but should be treated as a discarded first draft, not a
starting point — see `proofs/quarantined/README.md` for the full rationale
per file.

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

- Date (UTC): 2026-08-04
- Branch: `fix/theorem1-bft-compositional`
- Commands executed:
  - `cd proofs && lake build LeanFormalization Specification Refinement` — 8342 jobs
  - `python3 scripts/ci/lint_formal_proof_claims.py --repo-root .`
  - `bash scripts/ci/validate_formal_traceability.sh`
  - `python3 scripts/ci/generate_formal_validation_report.py --repo-root .`
  - `python3 scripts/ci/generate_formal_validation_report.py --repo-root . --check`
  - `python3 scripts/ci/check_markdown_links.py`
- Results:
  - Lean build: pass, only 1 `sorry` remains in the whole `proofs/LeanFormalization`
    tree (`RDP_sequential_composition`, deliberately left open — see its row 2 note)
  - Vacuous/misleading-theorem lint: pass (24 Lean files checked)
  - Traceability validation: pass (`10` modules, `74` theorem symbols, `30` runtime
    test refs)
  - Formal validation report consistency: pass after regeneration
  - Markdown link check: pass (167 files)
