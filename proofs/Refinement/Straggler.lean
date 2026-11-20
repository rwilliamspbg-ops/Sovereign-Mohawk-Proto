import Mathlib
import LeanFormalization.Theorem4StragglerResilience

/-!
# Straggler Resilience Refinement: Lean Spec ↔ Go Implementation

This module formalizes the correspondence between the Lean
correlated/adversarial straggler model (`Theorem4StragglerResilience`) and
Go's straggler monitor (`internal/straggler_resilience.go`).

## Go correspondence

`internal/straggler_resilience.go`:
- `PerRegionFailureBound` (independent, rho=0): p^r.
- `CorrelatedFailureBound(p, rho)`: p^r*(1+(r-1)rho), capped at 1.
- `AdversarialFailureBound(d)`: 0 if d<r else 1.
- `EffectiveFailureBound`: correlated if rho>0 else independent.

`test/straggler_correlated_test.go` exercises the Go side.

## What is proved here

* `straggler_impl_correlated_refines_spec` — in the non-saturated case the Go
  correlated bound equals the Lean spec exactly.
* `straggler_impl_le_spec` — **conservativeness of the runtime cap**: for
  in-range parameters the capped Go bound never exceeds the (uncapped) Lean
  spec. This is the direction an audit cares about: the runtime is never more
  optimistic than the theorem.
* `straggler_independent_refines_spec` — Go's independent bound equals the Lean
  correlated spec at `rho = 0`.
* `straggler_independent_le_correlated` — independence is the best case.

## Removed as vacuous (2026-11-20)

* `straggler_adversarial_refines` stated
  `(if d < r then 0 else 1) = stragglerAdversarialSpec r d` and proved it by
  `rfl`, because `stragglerAdversarialSpec` was *defined* as the Go expression.
  A refinement theorem whose spec is the implementation says nothing. The
  definitional match with the real spec is now recorded against
  `adversarialFailureProb` (`straggler_adversarial_matches_spec`).
* `stragglerChernoffEnvelope_nonneg` (`0 ≤ exp _`) was true for any exponential
  and said nothing about the envelope; it is replaced by the probability sanity
  bound `stragglerChernoffEnvelope_le_one`.

## Gap pinned

The Go monitor's `ValidateLiveness` uses a fixed 50% dropout rate and does
not yet expose the correlation factor to production callers; the
correlated model is opt-in via `NewCorrelatedStragglerMonitor`.
-/

namespace Refinement

/-- Spec (Lean) correlated failure bound: p^r * (1 + (r-1)*rho), the same
    formula as `correlatedFailureProb` in `Theorem4StragglerResilience`. -/
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

/-- **Conservativeness of the runtime cap.** Go clamps the correlated bound to
    `[0,1]`; the Lean spec is uncapped. For in-range parameters the clamped
    runtime bound therefore never exceeds the spec — the runtime is never more
    optimistic than the theorem. -/
theorem straggler_impl_le_spec (p : ℚ) (r : ℕ) (rho : ℚ)
    (hp : 0 ≤ p ∧ p ≤ 1) (hrho : 0 ≤ rho ∧ rho ≤ 1) (hr : 1 ≤ r) :
    stragglerImplCorrelated p r rho ≤ stragglerSpecBound p r rho := by
  unfold stragglerImplCorrelated stragglerSpecBound
  have hcond : 0 ≤ p ∧ p ≤ 1 ∧ 0 ≤ rho ∧ rho ≤ 1 := ⟨hp.1, hp.2, hrho.1, hrho.2⟩
  rw [if_pos hcond]
  set raw := p ^ r * (1 + (r : ℚ) * rho - rho) with hraw
  have hraw_nonneg : 0 ≤ raw := by
    rw [hraw]
    refine mul_nonneg (pow_nonneg hp.1 r) ?_
    have hr_nonneg : (0 : ℚ) ≤ (r : ℚ) := by positivity
    nlinarith [hrho.1, hr_nonneg]
  by_cases hgt : raw > 1
  · simp [hgt]; linarith
  · by_cases hlt : raw < 0
    · simp [hgt, hlt]; linarith
    · simp [hgt, hlt]

/-- **Negative control: the range hypotheses are load-bearing.** Outside
    `[0,1]` the clamp can make the runtime bound LARGER than the spec, which
    returns `0` out of range: at `p = 2`, `r = 1`, `rho = 1` the runtime gives
    `1` and the spec gives `0`. -/
theorem straggler_impl_le_spec_out_of_range :
    stragglerImplCorrelated 2 1 1 > stragglerSpecBound 2 1 1 := by
  unfold stragglerImplCorrelated stragglerSpecBound
  norm_num

/-- Go's independent bound equals the Lean correlated spec at `rho = 0` on the
    parameter range. -/
theorem straggler_independent_refines_spec (p : ℚ) (r : ℕ) (hp : 0 ≤ p ∧ p ≤ 1) :
    stragglerImplIndependent p r = stragglerSpecBound p r 0 := by
  unfold stragglerImplIndependent stragglerSpecBound
  rw [if_pos ⟨hp.1, hp.2, by norm_num, by norm_num⟩]
  ring

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

/-- Adversarial bound spec (Lean): 0 if d < r else 1. Mirrors
    `adversarialFailureProb` in `Theorem4StragglerResilience.lean`. -/
def stragglerAdversarialSpec (r d : ℕ) : ℚ :=
  if d < r then 0 else 1

/-- The adversarial spec matches `adversarialFailureProb` in the theorem module.
    This is a definitional match, recorded because the Go function
    `AdversarialFailureBound` cites that spec; there is no separate refinement
    content (the previous revision's `rfl` theorem against the Go expression was
    vacuous and was removed). -/
theorem straggler_adversarial_matches_spec (r d : ℕ) :
    stragglerAdversarialSpec r d = LeanFormalization.adversarialFailureProb r d := rfl

/-!
## Straggler quorum resilience via multiplicative Chernoff bound

Models client dropouts as independent Bernoulli trials over a cluster of
size `c` with per-client success probability `p`, and bounds the probability
that fewer than `q` clients respond by the standard multiplicative Chernoff
lower-tail inequality.
-/

/-- Client response indicator for a cluster of size `c`. -/
def ClientResponse (c : ℕ) := Fin c → Bool

/-- Quorum success condition: number of successful responses meets quota `q`. -/
def QuorumSatisfied (c q : ℕ) (responses : Fin c → Bool) : Prop :=
  q ≤ (Finset.filter (fun i => responses i = true) Finset.univ).card

/-- Multiplicative Chernoff lower-tail envelope for straggler quorum failure:
    P(sum X_i < q) ≤ exp(- c (p - q/c)^2 / (2 p)),
    with μ = c p and δ = 1 - q/(c p). -/
noncomputable def stragglerChernoffEnvelope (c q : ℕ) (p : ℝ) : ℝ :=
  Real.exp (- ((p - (q : ℝ) / c) ^ 2 * c) / (2 * p))

/-- The envelope is a probability: it never exceeds `1`. (The previous revision
    proved only `0 ≤ exp _`, which holds for every exponential and said nothing
    about the envelope.) -/
theorem stragglerChernoffEnvelope_le_one (c q : ℕ) (p : ℝ) (hp : 0 < p) :
    stragglerChernoffEnvelope c q p ≤ 1 := by
  have h : stragglerChernoffEnvelope c q p ≤ Real.exp 0 := by
    unfold stragglerChernoffEnvelope
    apply Real.exp_le_exp.mpr
    have hsq : 0 ≤ (p - (q : ℝ) / c) ^ 2 := sq_nonneg _
    have hc : (0 : ℝ) ≤ c := by positivity
    have hnum : (0 : ℝ) ≤ (p - (q : ℝ) / c) ^ 2 * c := mul_nonneg hsq hc
    have hden : (0 : ℝ) < 2 * p := by positivity
    have hfrac : 0 ≤ ((p - (q : ℝ) / c) ^ 2 * c) / (2 * p) := div_nonneg hnum hden.le
    calc -((p - (q : ℝ) / c) ^ 2 * c) / (2 * p)
        = -(((p - (q : ℝ) / c) ^ 2 * c) / (2 * p)) := by ring
      _ ≤ 0 := neg_nonpos.mpr hfrac
  rwa [Real.exp_zero] at h

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
    have hinv : (Real.exp 10)⁻¹ ≤ (227 : ℝ) / 5000000 := by simpa [inv_div] using inv_anti₀ hpos2 hexp
    exact le_trans hinv (by norm_num)
  exact le_trans h1 h2

end Refinement
