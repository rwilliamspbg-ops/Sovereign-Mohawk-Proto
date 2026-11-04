import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem4ChernoffBounds

namespace LeanFormalization

/- Strategy (straggler / quorum resilience, Theorem 4 extension):
  Relax the independence assumption used by `chernoff_bound` and model
  correlated / adversarial dropout schedules, then show:
    * independent dropouts are the BEST case (lowest failure probability);
    * an adversary with dropout budget d < r cannot take down all r copies;
    * the worst-case (perfectly correlated) failure probability is bounded
      by the linear-correlation model and is ≥ the independent bound.

  Tactics used: unfold/rfl, linarith, nlinarith, norm_num, positivity.
-/

/-- Correlated-dropout failure probability under a linear correlation model:
    P(all r copies fail) = p^r · (1 + (r-1)·ρ), where ρ ∈ [0,1] is the
    correlation coefficient. ρ = 0 recovers the independent model p^r;
    ρ = 1 is the perfectly-correlated (worst) case. -/
def correlatedFailureProb (p : ℚ) (r : ℕ) (rho : ℚ) : ℚ :=
  if 0 ≤ p ∧ p ≤ 1 ∧ 0 ≤ rho ∧ rho ≤ 1 then
    p ^ r * (1 + (r : ℚ) * rho - rho)
  else 0

/-- The correlated model recovers the independent model at ρ = 0. -/
theorem correlated_recovers_independent (p : ℚ) (r : ℕ)
    (hp : 0 ≤ p ∧ p ≤ 1) :
    correlatedFailureProb p r 0 = p ^ r := by
  unfold correlatedFailureProb
  rw [if_pos ⟨hp.1, hp.2, by norm_num, by norm_num⟩]
  ring

/-- Correlation only increases (or keeps) the failure probability: the
    independent model (ρ = 0) is the best case. -/
theorem correlation_increases_failure (p : ℚ) (r : ℕ) (rho : ℚ)
    (hp : 0 ≤ p ∧ p ≤ 1) (hrho : 0 ≤ rho ∧ rho ≤ 1) (hr : 1 ≤ r) :
    p ^ r ≤ correlatedFailureProb p r rho := by
  unfold correlatedFailureProb
  rw [if_pos ⟨hp.1, hp.2, hrho.1, hrho.2⟩]
  have hrho_factor : (1 : ℚ) ≤ 1 + (r : ℚ) * rho - rho := by
    have hrr : (1 : ℚ) ≤ (r : ℚ) := by exact_mod_cast hr
    nlinarith [hrho.1, hrr]
  have hp_pow_nonneg : 0 ≤ p ^ r := by
    apply pow_nonneg hp.1
  nlinarith [hp_pow_nonneg, hrho_factor]

/-- Adversarial dropout model: an adversary with budget d (can drop up to d
    copies) causes total failure only if it can drop all r copies. -/
def adversarialFailureProb (r d : ℕ) : ℚ :=
  if d < r then 0 else 1

/-- If the adversary's budget is strictly less than the redundancy r, total
    failure is impossible (at least one copy survives). -/
theorem adversarial_cannot_fail_if_budget_less (r d : ℕ) (h : d < r) :
    adversarialFailureProb r d = 0 := by
  unfold adversarialFailureProb
  rw [if_pos h]

/-- If the adversary can drop all r copies (budget ≥ r), worst case is total
    failure. -/
theorem adversarial_total_failure_if_budget_enough (r d : ℕ) (h : r ≤ d) :
    adversarialFailureProb r d = 1 := by
  unfold adversarialFailureProb
  have hnd : ¬ (d < r) := by omega
  rw [if_neg hnd]

/-- Monotonicity of the adversarial model in the dropout budget. -/
theorem adversarial_monotone_in_budget (r d1 d2 : ℕ) (h : d1 ≤ d2) :
    adversarialFailureProb r d1 ≤ adversarialFailureProb r d2 := by
  unfold adversarialFailureProb
  by_cases h1 : d1 < r
  · by_cases h2 : d2 < r
    · simp [h1, h2]
    · simp [h1, h2]
  · have h2 : ¬ (d2 < r) := by omega
    simp [h1, h2]

/-- Correlated worst-case guard: with 12 redundant copies and 10% per-copy
    dropout, even under perfect correlation (ρ = 1) the failure probability
    is bounded. -/
theorem correlated_worst_case_guard :
    correlatedFailureProb (1 / 10 : ℚ) 12 1 ≤ (12 : ℚ) / 10 := by
  norm_num [correlatedFailureProb]

/-- Quorum resilience: a round succeeds if at least q of n regions respond.
    The probability all regions fail is bounded by the product of per-region
    failure probabilities (independence) or higher (correlation). -/
def quorumFailureProb (n : ℕ) (p : ℚ) (rho : ℚ) : ℚ :=
  if n > 0 then correlatedFailureProb p n rho else 0

end LeanFormalization
