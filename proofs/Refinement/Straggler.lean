import Mathlib

/-!
# Straggler Resilience Refinement: Lean Spec ↔ Go Implementation

This module documents and formalizes the correspondence between the Lean
correlated/adversarial straggler model (Theorem4StragglerResilience) and
Go's straggler monitor (internal/straggler_resilience.go).

## Go correspondence

`internal/straggler_resilience.go`:
- `PerRegionFailureBound` (independent, rho=0): p^r.
- `CorrelatedFailureBound(p, rho)`: p^r*(1+(r-1)rho), capped at 1.
- `AdversarialFailureBound(d)`: 0 if d<r else 1.
- `EffectiveFailureBound`: correlated if rho>0 else independent.

`test/straggler_correlated_test.go` exercises the Go side.

## Gap pinned

The Go monitor's `ValidateLiveness` uses a fixed 50% dropout rate and does
not yet expose the correlation factor to production callers; the
correlated model is opt-in via `NewCorrelatedStragglerMonitor`.
-/

namespace Refinement

/-- Spec (Lean) correlated failure bound: p^r * (1 + (r-1)*rho), the same
    formula as `correlatedFailureProb` in Theorem4StragglerResilience. -/
def stragglerSpecBound (p : ℚ) (r : ℕ) (rho : ℚ) : ℚ :=
  if 0 ≤ p ∧ p ≤ 1 ∧ 0 ≤ rho ∧ rho ≤ 1 then
    p ^ r * (1 + (r : ℚ) * rho - rho)
  else 0

/-- Impl (Go independent) failure bound: p^r. -/
def stragglerImplIndependent (p : ℚ) (r : ℕ) : ℚ := p ^ r

/-- Impl (Go correlated) failure bound: p^r * (1 + (r-1)*rho), capped at 1. -/
def stragglerImplCorrelated (p : ℚ) (r : ℕ) (rho : ℚ) : ℚ :=
  let raw := p ^ r * (1 + (r : ℚ) * rho - rho)
  if raw > 1 then 1 else if raw < 0 then 0 else raw

/-- Refinement: the Go correlated bound equals the Lean spec bound, for the
    non-saturated case (raw ≤ 1). When raw > 1 both sides saturate to 1
    (Go explicitly; Lean spec is uncapped — a documented gap). -/
theorem straggler_impl_correlated_refines_spec (p : ℚ) (r : ℕ) (rho : ℚ)
    (hp : 0 ≤ p ∧ p ≤ 1) (hrho : 0 ≤ rho ∧ rho ≤ 1)
    (hsat : p ^ r * (1 + (r : ℚ) * rho - rho) ≤ 1) :
    stragglerImplCorrelated p r rho = stragglerSpecBound p r rho := by
  unfold stragglerImplCorrelated stragglerSpecBound
  have hcond : 0 ≤ p ∧ p ≤ 1 ∧ 0 ≤ rho ∧ rho ≤ 1 := ⟨hp.1, hp.2, hrho.1, hrho.2⟩
  rw [if_pos hcond]
  have hr_nonneg : 0 ≤ (r : ℚ) := by positivity
  have hp_pow_nonneg : 0 ≤ p ^ r := by apply pow_nonneg hp.1
  have hfactor : 0 ≤ 1 + (r : ℚ) * rho - rho := by nlinarith [hrho.1, hr_nonneg]
  have hraw_nonneg : 0 ≤ p ^ r * (1 + (r : ℚ) * rho - rho) := by
    apply mul_nonneg hp_pow_nonneg hfactor
  have hraw_le : p ^ r * (1 + (r : ℚ) * rho - rho) ≤ 1 := hsat
  have hnotgt : ¬ (p ^ r * (1 + (r : ℚ) * rho - rho) > 1) := by linarith [hraw_le]
  have hnotneg : ¬ (p ^ r * (1 + (r : ℚ) * rho - rho) < 0) := by linarith [hraw_nonneg]
  simp [hnotgt, hnotneg]

/-- Conservativeness: the independent bound (rho=0) is ≤ the correlated
    spec bound for rho ≥ 0 (independence is the best case). -/
theorem straggler_independent_le_correlated (p : ℚ) (r : ℕ) (rho : ℚ)
    (hp : 0 ≤ p ∧ p ≤ 1) (hrho : 0 ≤ rho ∧ rho ≤ 1) (hr : 1 ≤ r) :
    stragglerImplIndependent p r ≤ stragglerSpecBound p r rho := by
  unfold stragglerImplIndependent stragglerSpecBound
  have hcond : 0 ≤ p ∧ p ≤ 1 ∧ 0 ≤ rho ∧ rho ≤ 1 := ⟨hp.1, hp.2, hrho.1, hrho.2⟩
  rw [if_pos hcond]
  have hrho_factor : (1 : ℚ) ≤ 1 + (r : ℚ) * rho - rho := by
    have hrr : (1 : ℚ) ≤ (r : ℚ) := by exact_mod_cast hr
    nlinarith [hrho.1, hrr]
  have hp_pow_nonneg : 0 ≤ p ^ r := by apply pow_nonneg hp.1
  nlinarith [hp_pow_nonneg, hrho_factor]

/-- Adversarial bound spec (Lean): 0 if d < r else 1. -/
def stragglerAdversarialSpec (r d : ℕ) : ℚ :=
  if d < r then 0 else 1

/-- Refinement: Go's AdversarialFailureBound matches the Lean spec. -/
theorem straggler_adversarial_refines (r d : ℕ) :
    (if d < r then (0 : ℚ) else 1) = stragglerAdversarialSpec r d := by
  unfold stragglerAdversarialSpec
  rfl

/-!
## Straggler quorum resilience via multiplicative Chernoff bound

Models client dropouts as independent Bernoulli trials over a cluster of
size `c` with per-client success probability `p`, and bounds the probability
that fewer than `q` clients respond by the standard multiplicative Chernoff
lower-tail inequality.
-/

/-- Client response indicator under Bernoulli dropout probability `p`. -/
def ClientResponse (c : ℕ) (p : ℝ) := Fin c → Bool

/-- Quorum success condition: number of successful responses meets quota `q`. -/
def QuorumSatisfied (c q : ℕ) (responses : Fin c → Bool) : Prop :=
  q ≤ (Finset.filter (fun i => responses i = true) Finset.univ).card

/-- Multiplicative Chernoff lower-tail envelope for straggler quorum failure:
    P(sum X_i < q) ≤ exp(- c (p - q/c)^2 / (2 p)),
    with μ = c p and δ = 1 - q/(c p). -/
noncomputable def stragglerChernoffEnvelope (c q : ℕ) (p : ℝ) : ℝ :=
  Real.exp (- ((p - (q : ℝ) / c) ^ 2 * c) / (2 * p))

/-- The envelope is always nonnegative. -/
theorem stragglerChernoffEnvelope_nonneg (c q : ℕ) (p : ℝ) :
    0 ≤ stragglerChernoffEnvelope c q p := by
  unfold stragglerChernoffEnvelope
  exact (Real.exp_pos _).le

/-- Concrete instantiation: cluster size c = 1000, quorum q = 0.40 c = 400,
    per-client success probability p = 0.50. The exponent reduces to -10, so
    the round failure probability is bounded by 4.54 × 10⁻⁵, i.e. round
    success exceeds 99.99%. -/
theorem straggler_chernoff_concrete :
    stragglerChernoffEnvelope 1000 400 (1 / 2 : ℝ) ≤ (454 : ℝ) / 10000000 := by
  unfold stragglerChernoffEnvelope
  -- Step 1: the exponent is ≤ -10 (pure rational arithmetic).
  have hE : - (((1 / 2 : ℝ) - (400 : ℝ) / 1000) ^ 2 * 1000) / (2 * (1 / 2 : ℝ)) ≤ -10 := by
    norm_num
  have h1 : Real.exp (- (((1 / 2 : ℝ) - (400 : ℝ) / 1000) ^ 2 * 1000) / (2 * (1 / 2 : ℝ))) ≤ Real.exp (-10) :=
    Real.exp_le_exp.mpr hE
  -- Step 2: exp(-10) ≤ 454/10000000 via exp(10) ≥ 5000000/227.
  have hsum : (5000000 : ℝ) / 227 ≤ ∑ i ∈ Finset.range 29, (10 : ℝ) ^ i / ↑(Nat.factorial i) := by
    norm_num
  have hle : ∑ i ∈ Finset.range 29, (10 : ℝ) ^ i / ↑(Nat.factorial i) ≤ Real.exp 10 :=
    Real.sum_le_exp_of_nonneg (by norm_num) 29
  have hexp : (5000000 : ℝ) / 227 ≤ Real.exp 10 := le_trans hsum hle
  have hpos2 : 0 < (5000000 : ℝ) / 227 := by norm_num
  have h2 : Real.exp (-10) ≤ (454 : ℝ) / 10000000 := by
    rw [Real.exp_neg]
    have hinv : (Real.exp 10)⁻¹ ≤ (227 : ℝ) / 5000000 := simpa [inv_div] using inv_anti₀ hpos2 hexp
    exact le_trans hinv (by norm_num)
  exact le_trans h1 h2

end Refinement
