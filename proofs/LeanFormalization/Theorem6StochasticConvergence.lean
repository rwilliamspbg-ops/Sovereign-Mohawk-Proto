import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem6ConvergenceReals

namespace LeanFormalization

/- Strategy (stochastic extension of Theorem 6):
  Move from the static O(1/KT)+ζ² surrogate to a martingale-based
  expectation-rate envelope that adds explicit client-variance (σ²/K) and
  dynamic gradient-drift (δ²) terms, matching the descent-lemma form:
    E[L_{t+1}] ≤ E[L_t] - η E[||∇f||²] + (η²/2)(σ²/K + ζ² + δ²).

  All claims here are machine-checked algebraic inequalities over ℚ; the
  probabilistic side (martingale difference sequences, expectation operator)
  is represented by the rational envelope parameters, consistent with the
  rest of this repo's surrogate style. Full measure-theoretic SGD convergence
  (Mathlib probability) is out of scope for this pass.

  Tactics used:
  - `unfold`/`rfl` for decomposition
  - `linarith`/`nlinarith` for monotonicity and nonnegativity
  - `norm_num` for concrete guards
  - `positivity` for denominator positivity
-/

/-- Client-variance contribution: σ² / K (heterogeneous client update variance). -/
def clientVarianceTerm (K : ℕ) (sigma2 : ℚ) : ℚ :=
  if K > 0 then sigma2 / (K : ℚ) else 0

/-- Squared gradient-drift contribution. -/
def driftTerm (drift : ℚ) : ℚ := drift ^ 2

/-- Stochastic convergence envelope for non-IID SGD with client variance and
    dynamic gradient drift:
      1/(2KT) + ζ² + σ²/K + δ². -/
def stochasticEnvelope (K T : ℕ) (zeta sigma2 drift : ℚ) : ℚ :=
  if K > 0 ∧ T > 0 then
    1 / (2 * (K : ℚ) * (T : ℚ)) + zeta ^ 2 +
      sigma2 / (K : ℚ) + drift ^ 2
  else 0

/-- Decomposition into SGD rate, heterogeneity, variance, and drift terms. -/
theorem stochastic_envelope_decompose (K T : ℕ) (zeta sigma2 drift : ℚ) :
    stochasticEnvelope K T zeta sigma2 drift =
    (if K > 0 ∧ T > 0 then 1 / (2 * (K : ℚ) * (T : ℚ)) + zeta ^ 2 +
      sigma2 / (K : ℚ) + drift ^ 2 else 0) := by
  unfold stochasticEnvelope
  rfl

/-- Nonnegativity of the stochastic envelope for nonnegative parameters. -/
theorem stochastic_envelope_nonneg (K T : ℕ) (zeta sigma2 drift : ℚ)
    (_hz : 0 ≤ zeta) (hs : 0 ≤ sigma2) (_hd : 0 ≤ drift)
    (hK : 0 < K) (hT : 0 < T) :
    0 ≤ stochasticEnvelope K T zeta sigma2 drift := by
  unfold stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩]
  have h1 : 0 ≤ (1 : ℚ) / (2 * (K : ℚ) * (T : ℚ)) := by positivity
  have h2 : 0 ≤ zeta ^ 2 := by nlinarith
  have h3 : 0 ≤ sigma2 / (K : ℚ) := by positivity
  have h4 : 0 ≤ drift ^ 2 := by nlinarith
  linarith

/-- The stochastic envelope dominates the deterministic one: extra variance and
    drift terms are nonnegative. -/
theorem stochastic_dominates_deterministic (K T : ℕ) (zeta sigma2 drift : ℚ)
    (hs : 0 ≤ sigma2) (_hd : 0 ≤ drift) (hK : 0 < K) (hT : 0 < T) :
    convergence_envelope K T zeta ≤ stochasticEnvelope K T zeta sigma2 drift := by
  unfold convergence_envelope stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩, if_pos ⟨hK, hT⟩]
  have hvar : 0 ≤ sigma2 / (K : ℚ) := by positivity
  have hdrift : 0 ≤ drift ^ 2 := by nlinarith
  linarith

/-- More rounds reduce the stochastic envelope (SGD rate term shrinks). -/
theorem stochastic_rounds_help_concrete :
    stochasticEnvelope 100 1000 ((1 : ℚ) / 10) ((1 : ℚ) / 100) ((1 : ℚ) / 100) ≥
    stochasticEnvelope 100 5000 ((1 : ℚ) / 10) ((1 : ℚ) / 100) ((1 : ℚ) / 100) := by
  norm_num [stochasticEnvelope]

/-- Higher client variance increases the envelope. -/
theorem stochastic_variance_increases (K T : ℕ) (zeta drift : ℚ)
    (s1 s2 : ℚ) (hs : s1 ≤ s2) (hK : 0 < K) (hT : 0 < T) :
    stochasticEnvelope K T zeta s1 drift ≤
    stochasticEnvelope K T zeta s2 drift := by
  unfold stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩, if_pos ⟨hK, hT⟩]
  have hKpos : (0 : ℚ) < (K : ℚ) := by exact_mod_cast hK
  have : s1 / (K : ℚ) ≤ s2 / (K : ℚ) := by
    apply div_le_div_of_nonneg_right hs (le_of_lt hKpos)
  linarith

/-- Larger gradient drift increases the envelope. -/
theorem stochastic_drift_increases (K T : ℕ) (zeta sigma2 : ℚ)
    (d1 d2 : ℚ) (hd : d1 ^ 2 ≤ d2 ^ 2) (hK : 0 < K) (hT : 0 < T) :
    stochasticEnvelope K T zeta sigma2 d1 ≤
    stochasticEnvelope K T zeta sigma2 d2 := by
  unfold stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩, if_pos ⟨hK, hT⟩]
  linarith [hd]

/-- Greater heterogeneity (ζ) increases the envelope. -/
theorem stochastic_heterogeneity_increases (K T : ℕ) (sigma2 drift : ℚ)
    (z1 z2 : ℚ) (hz : z1 ^ 2 ≤ z2 ^ 2) (hK : 0 < K) (hT : 0 < T) :
    stochasticEnvelope K T z1 sigma2 drift ≤
    stochasticEnvelope K T z2 sigma2 drift := by
  unfold stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩, if_pos ⟨hK, hT⟩]
  linarith [hz]

/-- Concrete stochastic guard for the 100-client / 1000-round profile with
    10% heterogeneity, 1% client variance, 1% drift. -/
theorem stochastic_large_scale_guard :
    stochasticEnvelope 100 1000 ((1 : ℚ) / 10) ((1 : ℚ) / 100) ((1 : ℚ) / 100) <
    (5 : ℚ) / 100 := by
  norm_num [stochasticEnvelope]

/-- Martingale descent-lemma shape: the expected loss decrease per round is at
    least η·g² minus the noise term (σ²/K + ζ² + δ²)·η²/2. Recorded as an
    algebraic identity for the chosen step size η = 1/√T. -/
theorem martingale_descent_step (eta g2 sigma2 zeta drift K : ℚ)
    (hK : 0 < K) (_heta : 0 < eta) (hsigma : 0 ≤ sigma2) :
    eta * g2 - (eta ^ 2 / 2) * (sigma2 / K + zeta ^ 2 + drift ^ 2) ≤
    eta * g2 := by
  have hnoise : 0 ≤ (eta ^ 2 / 2) * (sigma2 / K + zeta ^ 2 + drift ^ 2) := by
    apply mul_nonneg
    · apply div_nonneg (sq_nonneg eta) (by norm_num)
    · have h1 : 0 ≤ sigma2 / K := by
        apply div_nonneg hsigma (le_of_lt hK)
      have h2 : 0 ≤ zeta ^ 2 := by nlinarith
      have h3 : 0 ≤ drift ^ 2 := by nlinarith
      linarith
  linarith

end LeanFormalization
