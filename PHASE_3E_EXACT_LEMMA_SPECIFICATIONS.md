# Phase 3e: Exact Lean Lemma Specifications for Proof Completion

**Purpose**: Provides the exact Lean 4 lemma/theorem signatures that need proofs filled in for Phase 3e, ready for targeted patches.

**Status**: Complete specification ready for implementation

---

## Lemma 1: Rényi Divergence Definition

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new definitions needed)

**Exact Specification**:

```lean
-- Rényi divergence of order α between two probability mass functions
def RenyiDivergence {α : Type*} (p q : PMF α) (order : ℝ) : ℝ :=
  if order = 1 then
    KLDiv p q  -- classical KL divergence limit case
  else
    (1 / (order - 1)) * Real.log (∑ x, (q x) ^ order / (p x) ^ (order - 1))

theorem RenyiDivergence_limit_KL (p q : PMF α) :
  Filter.Tendsto (fun α => RenyiDivergence p q α) (𝓝[≠] 1) (𝓝 (KLDiv p q)) := by
  sorry  -- FILL: Use L'Hôpital's rule or limit definition from Mathlib

theorem RenyiDivergence_nonneg (p q : PMF α) (order : ℝ) (h_order : 1 < order) :
  0 ≤ RenyiDivergence p q order := by
  sorry  -- FILL: Use log nonnegativity + Jensen's inequality (q̂x / (p x)^frac is convex)
```

**Proof Strategy**: 
- Use Mathlib's `PMF.sum_cond` for measure axioms
- Apply `Real.log_exp` for exponent handling
- Reference `Mathlib.Analysis.SpecialFunctions.Log` for log properties
- Use Jensen's inequality from Mathlib for convexity

**Difficulty**: ⭐⭐⭐⭐ | **LOC Estimate**: 25-40

---

## Lemma 2: Data Processing Inequality

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new lemma)

**Exact Specification**:

```lean
-- Data processing inequality: post-processing cannot increase Rényi divergence
theorem data_processing_inequality 
  {α β : Type*} (f : α → β) (p q : PMF α) (order : ℝ) 
  (h_order : 0 < order) (h_order_ne_1 : order ≠ 1) :
  RenyiDivergence (PMF.map f p) (PMF.map f q) order ≤ RenyiDivergence p q order := by
  sorry  -- FILL: Jensen's inequality for f^order convexity on mapped measures

theorem data_processing_inequality_KL
  {α β : Type*} (f : α → β) (p q : PMF α) :
  KLDiv (PMF.map f p) (PMF.map f q) ≤ KLDiv p q := by
  sorry  -- FILL: Kraft inequality / conditional divergence chain
```

**Proof Strategy**:
- Note that `f^order` is convex for `order > 1` (use `ConvexOn` from Mathlib)
- Apply Jensen's inequality: `E[f^order] ≥ (E[f])^order`
- Use sum factorization via `PMF.map_prod_eq_sum`
- Log monotonicity reduces to discrete Jensen's

**Difficulty**: ⭐⭐⭐⭐ | **LOC Estimate**: 40-60

---

## Lemma 3: Chain Rule for Rényi Divergence

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new lemma)

**Exact Specification**:

```lean
-- Chain rule decomposes joint divergence into marginal + conditional
theorem RenyiDiv_chain_rule 
  {α β : Type*} (p q : PMF (α × β)) (order : ℝ)
  (h_order : 1 < order) :
  let p_fst := PMF.fst p
  let q_fst := PMF.fst q
  RenyiDivergence p q order =
    RenyiDivergence p_fst q_fst order +
    ∫ x in p_fst.support, RenyiDivergence (p.cond_fst x) (q.cond_fst x) order := by
  sorry  -- FILL: Decompose joint measure into marginal × conditional factorization

theorem composition_via_chain_rule
  {α : Type*} (M1 M2 : α → PMF (α × α)) (eps1 eps2 : ℝ)
  (h_M1 : ∀ x y, RenyiDivergence (M1 x).fst (M1 y).fst 2 ≤ eps1)
  (h_M2 : ∀ x y, RenyiDivergence (M2 x).fst (M2 y).fst 2 ≤ eps2) :
  ∀ x y, RenyiDivergence ((M1 x).prod (M2 x)).fst ((M1 y).prod (M2 y)).fst 2 ≤ eps1 + eps2 := by
  sorry  -- FILL: Apply chain rule twice, then data_processing_inequality on outputs
```

**Proof Strategy**:
- Factor joint: `p(x,y) = p(x) × p(y|x)`
- Sum over first coordinate: `∑_(x,y) = ∑_x ∑_y|x`
- Extract log ratio for RenyiDiv definition
- Conditional entropy/divergence from Mathlib if available

**Difficulty**: ⭐⭐⭐⭐⭐ | **LOC Estimate**: 60-100

---

## Lemma 4: Sequential Composition Theorem (Core)

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new theorem)

**Exact Specification**:

```lean
-- Core composition: RDP bounds add under sequential execution
theorem RDP_sequential_composition
  {D : Type*} [DecidableEq D] 
  (M1 M2 : D → PMF D)  -- two mechanisms over same database space
  (eps1 eps2 α : ℝ)
  (h_alpha : 1 < α)
  (h_adj : ∀ d1 d2, distance d1 d2 ≤ 1)  -- adjacency via metric
  (h_RDP_M1 : ∀ d1 d2, distance d1 d2 ≤ 1 → RenyiDivergence (M1 d1) (M1 d2) α ≤ eps1)
  (h_RDP_M2 : ∀ d1 d2, distance d1 d2 ≤ 1 → RenyiDivergence (M2 d1) (M2 d2) α ≤ eps2) :
  ∀ d1 d2, distance d1 d2 ≤ 1 →
    RenyiDivergence 
      (PMF.prod (M1 d1) (M2 d1))
      (PMF.prod (M1 d2) (M2 d2))
      α ≤ eps1 + eps2 := by
  sorry  -- FILL: Chain rule + data_processing_inequality orchestration

-- Conversion to (ε, δ)-DP form
theorem RDP_to_eps_delta_conversion
  (eps_rdp : ℝ) (delta : ℝ) (alpha : ℝ)
  (h_alpha : 1 < alpha) (h_delta_pos : 0 < delta) :
  RenyiDivergence p q alpha ≤ eps_rdp →
    ∃ eps, eps = eps_rdp + (Real.log (1 / delta)) / (alpha - 1) ∧
    KLDiv p q ≤ eps := by
  sorry  -- FILL: Use RenyiDiv → KL limit + log rewriting
```

**Proof Strategy**:
- Express `PMF.prod (M1 d1) (M2 d1)` as product measure
- Apply RenyiDiv_chain_rule to get marginal + conditional
- Apply data_processing_inequality to marginals
- Sum bounds: `eps1 + eps2`
- Use KL limit for conversion

**Difficulty**: ⭐⭐⭐⭐⭐ | **LOC Estimate**: 80-120

---

## Lemma 5: Gaussian RDP Exact Bound

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new lemma)

**Exact Specification**:

```lean
-- Gaussian mechanism: add N(0, σ²) noise
def gaussian_mechanism (μ : ℝ) (sigma : ℝ) : PMF ℝ :=
  PMF.gaussian μ (sigma ^ 2)

-- Exact RDP bound for Gaussian
theorem gaussian_RDP_bound
  (mu1 mu2 : ℝ) (sigma : ℝ) (Alpha : ℝ)
  (h_sigma_pos : 0 < sigma) 
  (h_alpha : 1 < Alpha) :
  let p := gaussian_mechanism mu1 sigma
  let q := gaussian_mechanism mu2 sigma
  RenyiDivergence p q Alpha = (Alpha * (mu1 - mu2) ^ 2) / (2 * sigma ^ 2) := by
  sorry  -- FILL: Compute Gaussian likelihood ratio + integrate over support

theorem gaussian_mechanism_is_RDP_private
  (mu1 mu2 : ℝ) (sigma : ℝ) (Alpha : ℝ)
  (h_sigma_pos : 0 < sigma) (h_alpha : 1 < Alpha)
  (h_adj : |mu1 - mu2| ≤ 1) :  -- adjacency
  RenyiDivergence (gaussian_mechanism mu1 sigma) (gaussian_mechanism mu2 sigma) Alpha
    ≤ Alpha / (2 * sigma ^ 2) := by
  sorry  -- FILL: Apply gaussian_RDP_bound then substitute h_adj
```

**Proof Strategy**:
- Probability density: `f(x; μ, σ) = exp(-(x-μ)²/(2σ²)) / √(2πσ²)`
- Likelihood ratio: `q(x)/p(x) = exp((mu1²-mu2²)/(2σ²) + (mu2-mu1)x/σ²)`
- Rényi divergence integral: `∫ p(x)·(q(x)/p(x))^α dx` → Gaussian integral
- Complete the square in exponent
- Reduce to: `α/(2σ²) · (mu1-mu2)²`

**Difficulty**: ⭐⭐⭐⭐⭐ | **LOC Estimate**: 100-150

---

## Lemma 6: Clipped Gaussian (Optional Advanced)

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (optional new lemma)

**Exact Specification**:

```lean
-- Clipped Gaussian for numerical stability
def clipped_gaussian_mechanism (mu : ℝ) (sigma : ℝ) (clip : ℝ) : PMF ℝ :=
  let base := gaussian_mechanism mu sigma
  let clipped := PMF.cond base (fun x => |x| ≤ clip)
  clipped / (clipped.support.card : ℝ)

theorem clipped_gaussian_RDP_bound
  (mu1 mu2 : ℝ) (sigma : ℝ) (clip : ℝ) (Alpha : ℝ)
  (h_sigma_pos : 0 < sigma)
  (h_clip_pos : 0 < clip)
  (h_alpha : 1 < Alpha)
  (h_adj_within_clip : |mu1 - mu2| ≤ clip) :
  RenyiDivergence 
    (clipped_gaussian_mechanism mu1 sigma clip) 
    (clipped_gaussian_mechanism mu2 sigma clip) 
    Alpha
    ≤ (Alpha * (mu1 - mu2) ^ 2) / (2 * sigma ^ 2) := by
  sorry  -- FILL: Clipping adds diversity → divergence decreases; bound unchanged at support
```

**Proof Strategy**:
- Clipping reduces support but increases "uniform mass"
- By data_processing_inequality, divergence can only decrease
- Within clipped region, bound identical to unclipped Gaussian

**Difficulty**: ⭐⭐⭐⭐⭐⭐ | **LOC Estimate**: 120-180

---

## Lemma 7: Moment Accountant Equivalence

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new lemma)

**Exact Specification**:

```lean
-- Moment accountant: numerically stable variant of RDP
def moment_accountant (Alpha : ℝ) (M : α → PMF β) (d1 d2 : α) : ℝ :=
  let p := M d1
  let q := M d2
  Real.log (∑ y, (q y) ^ Alpha / (p y) ^ (Alpha - 1))

-- Equivalence to RDP
theorem moment_accountant_equals_RDP
  (Alpha : ℝ) (M : α → PMF β) (d1 d2 : α)
  (h_alpha : 1 < Alpha) :
  RenyiDivergence (M d1) (M d2) Alpha =
    (1 / (Alpha - 1)) * moment_accountant Alpha M d1 d2 := by
  sorry  -- FILL: Unfold definitions; factor out constants

-- Numerical stability equivalence
theorem moment_accountant_numerically_stable
  (Alpha : ℝ) (M : α → PMF β) (d1 d2 : α)
  (h_alpha : 1 < Alpha) :
  let rdp := RenyiDivergence (M d1) (M d2) Alpha
  let mom := (1 / (Alpha - 1)) * moment_accountant Alpha M d1 d2
  rdp = mom ∧ 
  (∀ ε > 0, |rdp - mom| < ε) := by
  sorry  -- FILL: Definitional equality + floating-point precision bound
```

**Proof Strategy**:
- Directly unfold both definitions
- Factor constants: `log(sum) = (A-1) · RDP`
- Rearrange algebraically
- Precision bound from Mathlib floating-point axioms

**Difficulty**: ⭐⭐⭐ | **LOC Estimate**: 30-50

---

## Lemma 8: Optimal α Selection

**Location**: `proofs/LeanFormalization/Theorem2RDP.lean` (new lemma)

**Exact Specification**:

```lean
-- Optimal Rényi order for n independent mechanisms with ε_i bounds
def optimal_alpha_order (n : ℕ) : ℝ :=
  Real.sqrt (2 * Real.log n)

theorem optimal_alpha_minimizes_composition
  (n : ℕ) (h_n : 2 ≤ n)
  (epsilons : Fin n → ℝ)
  (h_eps_pos : ∀ i, 0 < epsilons i) :
  let alpha_opt := optimal_alpha_order n
  let alpha_any := fun (a : ℝ) => 1 < a
  ∀ (alpha : ℝ), alpha_any alpha →
    (∑ i, (Alpha_opt * epsilons i) / (Alpha_opt - 1)) ≤
    (∑ i, (alpha * epsilons i) / (alpha - 1)) := by
  sorry  -- FILL: Take derivative w.r.t. α; verify critical point is minimum

-- Concrete bound for n steps
theorem composition_n_steps_optimal_bound
  (n : ℕ) (h_n : 2 ≤ n)
  (M : Fin n → (α → PMF β)) 
  (eps : ℝ) (h_eps : ∀ i, ∀ d1 d2, distance d1 d2 ≤ 1 →
    RenyiDivergence (M i d1) (M i d2) (optimal_alpha_order n) ≤ eps) :
  ∀ d1 d2, distance d1 d2 ≤ 1 →
    RenyiDivergence 
      (PMF.prod_fin (fun i => M i d1))
      (PMF.prod_fin (fun i => M i d2))
      (optimal_alpha_order n)
      ≤ (n : ℝ) * eps := by
  sorry  -- FILL: Induction over n; apply RDP_sequential_composition repeatedly
```

**Proof Strategy**:
- Compute total RDP: `T(α) = n · ε / (α-1)`
- Differentiate: `dT/dα = -n·ε / (α-1)²`
- Critical point satisfies: `α = √(2 log n)` (from optimization literature)
- Verify convexity: `d²T/dα² > 0`
- Apply by induction for n-fold composition

**Difficulty**: ⭐⭐⭐⭐ | **LOC Estimate**: 70-110

---

## Summary Table: All 8 Lemmas for Phase 3e

| # | Lemma Name | File | Type | Difficulty | LOC | Chain Rule | Data Proc | Gaussian | Notes |
|----|------------|------|------|-----------|-----|-----------|----------|----------|-------|
| 1 | RenyiDivergence_* | Theorem2RDP.lean | Def+2 theorems | ⭐⭐⭐⭐ | 25-40 | Foundational | — | — | Limit to KL |
| 2 | data_processing_inequality | Theorem2RDP.lean | 2 theorems | ⭐⭐⭐⭐ | 40-60 | — | **KEY** | — | Post-processing monotone |
| 3 | RenyiDiv_chain_rule | Theorem2RDP.lean | 2 theorems | ⭐⭐⭐⭐⭐ | 60-100 | **KEY** | Uses #2 | — | Joint factorization |
| 4 | RDP_sequential_composition | Theorem2RDP.lean | 3 theorems | ⭐⭐⭐⭐⭐ | 80-120 | Uses #3 | Uses #2 | — | Composition Theorem |
| 5 | gaussian_RDP_bound | Theorem2RDP.lean | 2 theorems | ⭐⭐⭐⭐⭐ | 100-150 | — | — | **KEY** | Exact formula |
| 6 | clipped_gaussian_* | Theorem2RDP.lean | 1 theorem | ⭐⭐⭐⭐⭐⭐ | 120-180 | — | Uses #2 | Uses #5 | Optional (advanced) |
| 7 | moment_accountant_* | Theorem2RDP.lean | 2 theorems | ⭐⭐⭐ | 30-50 | — | — | — | Definitional |
| 8 | optimal_alpha_* | Theorem2RDP.lean | 2 theorems | ⭐⭐⭐⭐ | 70-110 | Uses #3 | — | — | Optimization |

**Dependency Graph**:
```
#1 (RenyiDiv)
  ↓
#2 (Data Processing)
  ↓
#3 (Chain Rule) ← #2
  ↓
#4 (Sequential Composition) ← #3, #2
  ↓
#5 (Gaussian) — standalone
  ↓
#6 (Clipped Gaussian) ← #2, #5
  ↓
#7 (Moment Accountant) — standalone
  ↓
#8 (Optimal α) ← #3
```

**Implementation Order** (respecting dependencies):
1. Stage A: #1 → #2 → (foundations ready)
2. Stage B: #3 → #4 → (composition ready)
3. Stage C: #5 → #6 → (Gaussian ready)
4. Stage D: #7 → #8 → (optimization ready)

---

## Integration with Go Tests

All 8 lemmas have corresponding Go unit tests in:
- `test/phase3c_theorems_test.go` — tests #1, #2, #3, #4, #5, #7
- `test/phase3d_advanced_theorems_test.go` — tests #6, #8

Run tests to validate Lean proofs:
```bash
go test ./test -v -run "Phase3c|Phase3d"
```

---

## Next Steps

**For Targeted Patch**: Copy any lemma specification above and implement the proof body (replace `sorry` with actual proof tactics).

**For Phase 3e PR**: Stage implementations by dependency order above. Each complete proof unlocks downstream lemmas.

**Validation**: After each proof, run corresponding Go test and Lake build to verify integration.

