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
  rw [if_pos ⟨hp.1, hp.2, hrho.1, hrho.2⟩]
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
  rw [if_pos ⟨hp.1, hp.2, hrho.1, hrho.2⟩]
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

end Refinement