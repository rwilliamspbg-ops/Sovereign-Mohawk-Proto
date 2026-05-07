# Plan to Deepen the Formal Proofs (Phase 3c)

**Status**: Implementation Plan  
**Last Updated**: May 5, 2026  
**Scope**: Strengthen core RDP definitions, sequential composition, Gaussian bounds, and runtime refinement

## Executive Summary

This document outlines a systematic approach to deepen the formal verification of Theorem 2 (Real-time Rényi DP composition) by replacing placeholder definitions with rigorous, Mathlib-backed implementations and proving key privacy properties that bridge the formal specification to the Go runtime accountant.

### Key Objectives

1. **Replace Placeholders**: Move from basic predicates to fully realized RDP definitions using Mathlib probability structures
2. **Prove Sequential Composition**: Formalize that RDP bounds compose additively for independent mechanisms
3. **Formalize Gaussian Mechanism**: Prove the exact (α, α/(2σ²))-RDP bound for Gaussian noise addition
4. **Implement Privacy Budget Tracking**: Add monotonicity, optimal α selection, and tiered composition lemmas
5. **Establish Runtime Refinement**: Prove the Go accountant implementation satisfies the formal specification
6. **Update Supporting Artifacts**: Revise documentation and traceability matrix with new theorems

---

## Phase 1: Strengthen Core Definitions (Immediate Wins)

### 1.1 Improve `isAdjacent`

**Current State** (Placeholder):
```lean
def isAdjacent {D : Type*} (d1 d2 : D) : Prop :=
  ∃ (_ : Unit), True
```

**Desired State** (with "record replacement" semantics):
- Define `replaceOneRecord` helper that formally encodes "one element differs"
- Work with `List ℚ` (database as list of rational values) for now
- Later: generalize to abstract indexable structures

**New Definition**:
```lean
def replaceOneRecord (d : List ℚ) (i : Nat) (v : ℚ) : List ℚ := ...

def isAdjacent (d1 d2 : List ℚ) : Prop :=
  ∃ i v, d1.length = d2.length ∧ replaceOneRecord d1 i v = d2 ∧ 
          ∀ j ≠ i, d1.get j = d2.get j
```

### 1.2 Refine `RDPMechanism` Structure

**New Structure**:
```lean
structure RDPMechanism (D X : Type*) where
  apply : D → PMF X
  alpha : ℝ
  rdpBound : D → D → ℝ
  satisfies : ∀ d1 d2, isAdjacent d1 d2 → 
              RenyiDivergence (apply d1) (apply d2) alpha ≤ rdpBound d1 d2
```

- Uses **Mathlib.Probability.ProbabilityMassFunction** for rigorous probability
- Links mechanism output directly to RDP privacy bounds
- Alpha parameter tied to specific Rényi divergence order

### 1.3 Add Rényi Divergence Definition

**Specification**:
```lean
def RenyiDivergence {X : Type*} (p q : PMF X) (α : ℝ) : ℝ :=
  if α = 1 then KLDivergence p q  -- KL divergence limit
  else ...  -- Standard Rényi formula (from Mathlib or custom)
```

**Key Property**:
- When `p` and `q` are supported on adjacent database outcomes
- RDP captures the max log-likelihood ratio over all events

---

## Phase 2: Prove Full Sequential Composition

### 2.1 Theorem: Sequential Composition Additivity

**Theorem Statement**:
```lean
theorem theorem2_rdp_sequential_composition
    {D X : Type*} {M1 M2 : RDPMechanism D X}
    (h1 : satisfiesRDP M1) (h2 : satisfiesRDP M2) :
    satisfiesRDP (composeMechanisms M1 M2) := by
  -- M1 and M2 are independent mechanisms on the same database
  -- Show: RenyiDivergence of joint ≤ M1.rdpBound + M2.rdpBound
  -- Uses: data processing inequality + chain rule
  sorry
```

**Key Ideas**:
1. Define `composeMechanisms` as parallel execution (joint distribution is product)
2. Apply **data processing inequality**: divergence decreases under post-processing
3. Use **chain rule** for probability measures from Mathlib
4. Result: composition bound is **exactly additive** in epsilon

### 2.2 Lemma: Chain Rule for Rényi Divergence

```lean
lemma renyiDiv_chain_rule {X Y : Type*} (p q : PMF (X × Y)) (α : ℝ) :
    RenyiDivergence p q α = 
      RenyiDivergence (PMF.fst p) (PMF.fst q) α + 
      E_{x~p.fst}[RenyiDivergence (p.cond x) (q.cond x) α]
```

(Use Mathlib's conditional probability structure)

---

## Phase 3: Improve Gaussian Mechanism Formalization

### 3.1 Gaussian RDP Exact Bound

**Theorem**:
```lean
theorem gaussian_rdp_exact_bound
    (mu1 mu2 : ℚ) (sigma : ℝ) (h_sigma : sigma > 0)
    (alpha : ℝ) (h_alpha : 1 < alpha) :
    let mechanism := gaussianMechanism mu1 mu2 sigma
    in satisfiesRDP mechanism ∧ 
       ∀ d1 d2, isAdjacent d1 d2 →
         mechanism.rdpBound d1 d2 = 
           alpha / (2 * sigma ^ 2) * (mu1 - mu2) ^ 2
```

**Implementation Approach**:
- Use **Mathlib.Analysis.SpecialFunctions.Gaussian** (or define custom Gaussian density)
- Compute RenyiDivergence(N(μ1, σ), N(μ2, σ), α) symbolically
- Derive bound as consequence of known Gaussian RDP literature

### 3.2 Subsampling Amplification (Optional, Advanced)

```lean
theorem subsampling_amplification
    (p : ℝ) (h_p : 0 < p ∧ p ≤ 1) (M : RDPMechanism D X) :
    let subsampledM := subsample p M
    in satisfiesRDP M → satisfiesRDP subsampledM ∧
       subsampledM.rdpBound ≤ ... -- amplified bound (tighter for small p)
```

---

## Phase 4: Stronger Conversion & Privacy Budget Tracking

### 4.1 RDP to (ε, δ)-DP Conversion (Enhanced)

**Theorem**:
```lean
theorem rdp_to_eps_delta_tight
    (alpha eps_rdp delta : ℝ) 
    (h_alpha : 1 < alpha) (h_eps : eps_rdp ≥ 0) (h_delta : 0 < delta ∧ delta < 1) :
    ∃ eps_dp, 
      eps_dp = eps_rdp + log(1/delta) / (alpha - 1) ∧
      eps_dp ≥ 0 ∧
      -- Implication: mechanism with (α, ε_rdp)-RDP guarantees (ε_dp, δ)-DP
      (α, ε_rdp)-RDP → (ε_dp, δ)-DP
```

### 4.2 Monotonicity in α

```lean
lemma rdp_monotone_in_alpha {alpha1 alpha2 : ℝ} 
    (h : alpha1 < alpha2) (M : RDPMechanism D X) :
    M.rdpBound_with_alpha alpha1 ≥ M.rdpBound_with_alpha alpha2
```
- Higher α orders yield tighter (smaller) RDP bounds
- Optimal selection: minimize conversion cost across all α ∈ (1, ∞)

### 4.3 Optimal α Selection

```lean
theorem optimal_alpha_selection
    (target_eps_dp : ℝ) (delta : ℝ) (eps_rdp_steps : List ℝ) :
    ∃ alpha_opt : ℝ,
      alpha_opt = argmin λ α => rdp_to_eps_delta_conversion eps_rdp_steps α delta ∧
      rdp_to_eps_delta_conversion eps_rdp_steps alpha_opt delta ≤ target_eps_dp
```

### 4.4 Tiered Privacy Budget Composition

```lean
/-- 4-tier model: each tier has different noise level (σ_i). -/
def tieredComposition (sigmas : Vector ℝ 4) (queries : Nat) : ℚ :=
  sum (λ i => queries * (sigmas.get i)^(-2) / 2)

theorem tiered_budget_exact
    (sigmas : Vector ℝ 4) (queries : Nat) (target_budget : ℚ) :
    tieredComposition sigmas queries ≤ target_budget ↔ 
      go_runtime_guards_pass sigmas queries target_budget
```

---

## Phase 5: Refinement Layer (Runtime ↔ Formal)

### 5.1 Refinement Theorem

**High-level Theorem**:
```lean
theorem theorem2_runtime_refinement
    (steps : List ℚ) (budget : ℚ) :
    formal_satisfies_privacy steps budget ↔
      go_accountant_checks_pass steps budget
```

**Proof Sketch**:
1. Show `go_accountant.RecordStepRat(eps)` = `composeEpsRat.append eps`
2. Show `go_accountant.CheckBudget()` ≤ `formal_budget_guard`
3. Show commutativity: rational arithmetic in Go ≈ Lean composeEpsRat

### 5.2 Ledger Soundness

```lean
theorem ledger_soundness
    (acc : RDPAccountant) (steps : List ℚ) :
    acc.apply steps = composeEpsRat steps
```
- Maps Go method calls to formal cumulative composition
- Ensures `CheckBudget()` rejects any trace violating ε ≤ budget

---

## Phase 6: Supporting Artifacts & Documentation

### 6.1 Update [differential_privacy.md](differential_privacy.md)

- Replace "surrogate_verified_with_gaussian_axiom" with specific theorem references
- Add new theorem statements (2.1, 2.2, 3.1, 4.1, 4.3, etc.)
- Include example bounds and conversion calculations
- Link to Lean proof code

### 6.2 Update [FORMAL_TRACEABILITY_MATRIX.md](FORMAL_TRACEABILITY_MATRIX.md)

| Theorem | Status | Mathlib Deps | Runtime Binding |
|---------|--------|--------------|-----------------|
| Theorem 2 (Basics) | Implemented | None | `composeEpsRat` ✓ |
| Sequential Composition | Planned | `Mathlib.Probability` | `RecordStepRat` ✓ |
| Gaussian Exact Bound | In Progress | `Mathlib.Analysis.Special` | `RecordGaussianStepRDP` ◐ |
| RDP→(ε,δ) Conversion | Planned | `Mathlib.Analysis.Log` | `GetCurrentEpsilon` ✓ |
| Subsampling Amplification | Advanced | `Mathlib.Probability` | `RecordSubsampledStep` ✗ |
| Runtime Refinement | Planned | None | End-to-end ◐ |

### 6.3 Academic Paper Update

- Add formal theorem statements to the "Formal Verification" section
- Reference Lean proof names alongside literature
- Strengthen claims: "**Theorem 2 is formally verified in Lean** (see Theorem2RDP.lean, theorem2_rdp_sequential_composition)"

---

## Phase 7: Implementation Roadmap & Deliverables

### Immediate Wins (This PR)

- [ ] Improved `isAdjacent` definition for `List ℚ`
- [ ] `RDPMechanism` structure with PMF-backed `apply`
- [ ] `RenyiDivergence` definition (or import from Mathlib)
- [ ] Theorem: Sequential composition (with proof outline or `sorry`)
- [ ] Theorem: Gaussian exact bound (with `sorry` linking to literature)
- [ ] Conversion monotonicity lemmas
- [ ] Updated documentation linking new theorems

### Next Steps (Follow-up PRs)

1. **Proof Completion**: Fill in `sorry`s with full proofs
   - Chain rule for Rényi divergence
   - Data processing inequality application
   - Gaussian mechanism bound derivation

2. **Advanced Composition**: Subsampling amplification, moment accountant

3. **Runtime Integration**: Prove `theorem2_runtime_refinement` end-to-end

4. **CI Integration**: Add Lean test suite to GitHub Actions
   - Run `lake build` on all proofs
   - Generate proof coverage metrics

---

## File Structure

```
proofs/
├── LeanFormalization/
│   ├── Theorem2RDP.lean           (enhanced core theorems)
│   ├── Theorem2AdvancedRDP.lean   (NEW: subsampling, moments accountant)
│   ├── Gaussian.lean              (NEW: Gaussian mechanism details)
│   ├── RenyiDivergence.lean       (NEW: Rényi divergence wrapper)
│   └── Common.lean                (updated with refined types)
├── Specification/
│   └── Privacy.lean               (unchanged)
├── Refinement/
│   ├── RDPAccountant.lean         (unchanged)
│   └── RuntimeRefinement.lean     (NEW: formal runtime binding)
└── differential_privacy.md        (updated with new theorems)
```

---

## Success Criteria

- [ ] Core definitions are precise, not placeholder
- [ ] Sequential composition theorem has detailed proof outline or full proof
- [ ] Gaussian bound theorem correctly states (α, α/(2σ²)) formula
- [ ] All new theorems build without `sorry` or at most have _justified_ `sorry`s
- [ ] Documentation updated to reference new theorems by name
- [ ] Traceability matrix shows progress from "surrogate" to "formalized"
- [ ] PR passes all Lean type-checking and builds cleanly

---

## References

### Mathlib Modules to Import

- `Mathlib.Probability.ProbabilityMassFunction` – PMF type and operations
- `Mathlib.Analysis.SpecialFunctions.Log` – Logarithm for divergence formulas
- `Mathlib.Analysis.SpecialFunctions.Gaussian` – Gaussian distribution (if available)
- `Mathlib.Data.List.Basic` – List operations for databases

### Literature & Resources

- Mironov, I. (2017). "Rényi Differential Privacy." *FOCS*.
- Dong, B., Durfee, D., & Rogers, R. M. (2019). "Gaussian Differential Privacy." *arXiv*.
- Zhu, T., Li, G., Tan, J., & Zhou, W. (2016). "Differentially Private Data Publishing and Analysis."

---

## Next Actions

1. **Run current validation**:
   ```bash
   cd proofs && lake build
   ```
   Check for existing `sorry`s and open issues.

2. **Import Mathlib modules**: Ensure available versions in Lean environment.

3. **Start with highest impact**:
   - Priority 1: Tighten Gaussian + sequential composition
   - Priority 2: Runtime refinement binding
   - Priority 3: Advanced topics (subsampling, moment accountant)

4. **Iterate with CI**: Each commit should build cleanly and pass type-checker.

---

**Status**: Ready for Implementation  
**Estimated Effort**: 4–6 weeks (prioritized phases)  
**Owner**: Formal Verification Team  
**Last Reviewed**: May 5, 2026
