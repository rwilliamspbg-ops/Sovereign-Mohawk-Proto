import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem6ConvergenceReals
import LeanFormalization.Theorem6StochasticConvergence

namespace LeanFormalization

/-! Strategy (SGD convergence, Theorem 6 graduation)

The model is **expectation-based, not deterministic**: the per-round quantity
is the expected loss decrease predicted by the descent lemma, and the noise
enters through its variance `σ²`. The descent lemma itself is stated as an
explicit hypothesis (`DescentLemmaHypothesis`) because it needs smoothness and
convexity of the objective, which are not modelled here.

## Honest scope (corrected 2026-11-20)

A previous revision of this module's docstring said it was "built on Mathlib's
PMF (probability mass functions)" and that the `O(1/√T)` rate "follows by
choosing `η = 1/√T`". Neither was true:

* There is **no PMF, no probability measure and no `expectation`** in this
  file. `noiseVariance` was the identity function and every quantity is a
  bare `ℚ`. The "measure-theoretic" name refers to the expectation-based
  (rather than deterministic) *shape* of the bound, not to measure-theoretic
  machinery.
* `convergence_rate_from_descent` proved only `0 ≤ D·η + (L·σ²/2)·η` — a
  nonnegativity statement with no `T` in it. It did **not** prove a rate.

Both are fixed: `noiseVariance` is gone, and the rate is now really proved
(`convergence_rate_uniform`, with the `O(1/√T)` specialization in
`convergence_rate_sqrt_T`).

Tactics used: unfold/rfl, linarith, nlinarith, ring, field_simp, norm_num.
-/

/-- Martingale descent-lemma hypothesis, packaged as a structure so callers
    can supply smoothness/convexity evidence. -/
structure DescentLemmaHypothesis where
  eta : ℚ            -- step size
  L : ℚ             -- smoothness constant
  sigma2 : ℚ        -- noise variance E[||noise||²]
  g2 : ℚ            -- E[||∇f(w)||²]
  h_eta_pos : 0 < eta
  h_L_pos : 0 < L
  h_sigma2_nonneg : 0 ≤ sigma2
  h_g2_nonneg : 0 ≤ g2

/-- Per-round expected loss decrease predicted by the descent lemma:
    E[f(w_{t+1})] ≤ E[f(w_t)] - η·g² + (η²·L/2)·σ². -/
def descentStep (h : DescentLemmaHypothesis) : ℚ :=
  - h.eta * h.g2 + (h.eta ^ 2 * h.L / 2) * h.sigma2

/-- The descent step is bounded above by the noise term alone (since the
    gradient term is nonpositive). -/
theorem descent_step_le_noise (h : DescentLemmaHypothesis) :
    descentStep h ≤ (h.eta ^ 2 * h.L / 2) * h.sigma2 := by
  unfold descentStep
  have hg : 0 ≤ h.eta * h.g2 := by
    apply mul_nonneg (le_of_lt h.h_eta_pos) h.h_g2_nonneg
  linarith

/-- Telescoping: over T rounds the cumulative descent is T times the
    per-round step (constant-rate assumption). -/
def cumulativeDescent (h : DescentLemmaHypothesis) (T : ℕ) : ℚ :=
  (T : ℚ) * descentStep h

/-- **The telescoped descent bound.** Summing the per-round descent inequality
    over `T` rounds gives `T·η·g² ≤ D + T·(η²L/2)·σ²`, where `D` is the
    initial suboptimality `E[f(w_0)] - f*`. Stated as a predicate so the rate
    theorems are explicitly conditional on it. -/
def TelescopedDescent (T : ℕ) (D : ℚ) (h : DescentLemmaHypothesis) : Prop :=
  (T : ℚ) * h.eta * h.g2 ≤ D + (T : ℚ) * (h.eta ^ 2 * h.L / 2) * h.sigma2

/-- **The convergence rate.** From the telescoped descent bound, the (uniform)
    gradient norm is bounded by the initial suboptimality plus the accumulated
    noise, divided by the number of rounds:

        g² ≤ D/(T·η) + (η·L·σ²)/2

    This is the real content the previous revision's docstring advertised. -/
theorem convergence_rate_uniform (h : DescentLemmaHypothesis) (T : ℕ) (D : ℚ)
    (hT : 0 < T) (htel : TelescopedDescent T D h) :
    h.g2 ≤ D / ((T : ℚ) * h.eta) + (h.eta * h.L * h.sigma2) / 2 := by
  unfold TelescopedDescent at htel
  have hTq : (0 : ℚ) < (T : ℚ) := by exact_mod_cast hT
  have hpos : (0 : ℚ) < (T : ℚ) * h.eta := mul_pos hTq h.h_eta_pos
  have hne : (T : ℚ) * h.eta ≠ 0 := ne_of_gt hpos
  have hstep : (D + (T : ℚ) * (h.eta ^ 2 * h.L / 2) * h.sigma2) / ((T : ℚ) * h.eta)
      = D / ((T : ℚ) * h.eta) + (h.eta * h.L * h.sigma2) / 2 := by
    rw [div_add_div (a := D) (c := h.eta * h.L * h.sigma2)
        (b := (T : ℚ) * h.eta) (d := 2) hne (by norm_num : (2 : ℚ) ≠ 0)]
    rw [div_eq_div_iff hne (mul_ne_zero hne (by norm_num : (2 : ℚ) ≠ 0))]
    ring
  calc h.g2
      ≤ (D + (T : ℚ) * (h.eta ^ 2 * h.L / 2) * h.sigma2) / ((T : ℚ) * h.eta) := by
        rw [le_div_iff₀ hpos]
        ring_nf at htel ⊢
        exact htel
    _ = D / ((T : ℚ) * h.eta) + (h.eta * h.L * h.sigma2) / 2 := hstep

/-- The rate bound is nonnegative for nonnegative data. -/
theorem convergence_rate_nonneg (h : DescentLemmaHypothesis) (T : ℕ) (D : ℚ)
    (hD : 0 ≤ D) (hT : 0 < T) :
    0 ≤ D / ((T : ℚ) * h.eta) + (h.eta * h.L * h.sigma2) / 2 := by
  have hTq : (0 : ℚ) < (T : ℚ) := by exact_mod_cast hT
  have hpos : (0 : ℚ) < (T : ℚ) * h.eta := mul_pos hTq h.h_eta_pos
  have h1 : (0 : ℚ) ≤ D / ((T : ℚ) * h.eta) := div_nonneg hD hpos.le
  have h2 : (0 : ℚ) ≤ (h.eta * h.L * h.sigma2) / 2 := by
    apply div_nonneg
    · apply mul_nonneg (mul_nonneg (le_of_lt h.h_eta_pos) (le_of_lt h.h_L_pos)) h.h_sigma2_nonneg
    · norm_num
  linarith

/-- The telescoped bound over `ℝ`, uniform in the step size. Used to derive
    the `O(1/√T)` rate, whose optimal step size involves a square root. -/
theorem telescopedBound_real (T : ℕ) (D eta L sigma2 g2 : ℝ)
    (hT : 0 < (T : ℝ)) (heta : 0 < eta)
    (htel : (T : ℝ) * eta * g2 ≤ D + (T : ℝ) * (eta ^ 2 * L / 2) * sigma2) :
    g2 ≤ D / ((T : ℝ) * eta) + (eta * L * sigma2) / 2 := by
  have hne : (T : ℝ) * eta ≠ 0 := ne_of_gt (mul_pos hT heta)
  have hstep : (D + (T : ℝ) * (eta ^ 2 * L / 2) * sigma2) / ((T : ℝ) * eta)
      = D / ((T : ℝ) * eta) + (eta * L * sigma2) / 2 := by
    rw [div_add_div (a := D) (c := eta * L * sigma2)
        (b := (T : ℝ) * eta) (d := 2) hne (by norm_num : (2 : ℝ) ≠ 0)]
    rw [div_eq_div_iff hne (mul_ne_zero hne (by norm_num : (2 : ℝ) ≠ 0))]
    ring
  calc g2
      ≤ (D + (T : ℝ) * (eta ^ 2 * L / 2) * sigma2) / ((T : ℝ) * eta) := by
        rw [le_div_iff₀ (by positivity : (0 : ℝ) < (T : ℝ) * eta)]
        ring_nf at htel ⊢
        exact htel
    _ = D / ((T : ℝ) * eta) + (eta * L * sigma2) / 2 := hstep

/-- `sqrt x * b = sqrt (x * b^2)` for nonnegative `x` and `b`. -/
theorem sqrt_mul_sq (x b : ℝ) (hx : 0 ≤ x) (hb : 0 ≤ b) :
    Real.sqrt x * b = Real.sqrt (x * b ^ 2) := by
  rw [show b = Real.sqrt (b ^ 2) from (Real.sqrt_sq hb).symm]
  rw [show (Real.sqrt (b ^ 2)) ^ 2 = b ^ 2 from Real.sq_sqrt (by positivity : (0 : ℝ) ≤ b ^ 2)]
  rw [Real.sqrt_mul hx (b ^ 2)]

/-- **The `O(1/√T)` rate.** If the telescoped descent bound holds for every
    step size (it is a per-round inequality, so the step size may be chosen
    before training), then choosing
    `η = sqrt(2D/(L·σ²·T))` balances the two terms and yields

        g² ≤ sqrt(2·L·σ²·D / T).

    This is the rate the previous docstring claimed without proving. -/
theorem convergence_rate_sqrt_T (T : ℕ) (D L sigma2 g2 : ℝ)
    (hD : 0 < D) (hT : 0 < (T : ℝ)) (hL : 0 < L) (hsigma : 0 < sigma2)
    (hforall : ∀ eta : ℝ, 0 < eta →
      (T : ℝ) * eta * g2 ≤ D + (T : ℝ) * (eta ^ 2 * L / 2) * sigma2) :
    g2 ≤ Real.sqrt (2 * (L * sigma2 * D) / (T : ℝ)) := by
  set eta0 : ℝ := Real.sqrt (2 * D / (L * sigma2 * (T : ℝ))) with heta0_def
  have heta0_pos : 0 < eta0 := by
    rw [heta0_def]
    exact Real.sqrt_pos.mpr (by positivity)
  have hbound := telescopedBound_real T D eta0 L sigma2 g2 hT heta0_pos (hforall eta0 heta0_pos)
  -- At the optimal step size the two terms coincide, so the bound collapses
  -- to `eta0 * L * sigma2`, which equals `sqrt(2*L*sigma2*D/T)`.
  have hA : (0 : ℝ) ≤ L * sigma2 := mul_nonneg (le_of_lt hL) (le_of_lt hsigma)
  have hsq : eta0 ^ 2 = 2 * D / (L * sigma2 * (T : ℝ)) := by
    rw [heta0_def, Real.sq_sqrt (by positivity)]
  have hopt : D / ((T : ℝ) * eta0) = (eta0 * L * sigma2) / 2 := by
    have hne : (T : ℝ) * eta0 ≠ 0 := mul_ne_zero (ne_of_gt hT) (ne_of_gt heta0_pos)
    rw [div_eq_div_iff hne (by norm_num : (2 : ℝ) ≠ 0)]
    have hr : (eta0 * L * sigma2) * ((T : ℝ) * eta0)
        = eta0 ^ 2 * (L * sigma2 * (T : ℝ)) := by ring
    rw [hr, hsq]
    field_simp
  have hval : (eta0 * L * sigma2) / 2 + (eta0 * L * sigma2) / 2
      = Real.sqrt (2 * (L * sigma2 * D) / (T : ℝ)) := by
    have h2 : (eta0 * L * sigma2) / 2 + (eta0 * L * sigma2) / 2 = eta0 * L * sigma2 := by ring
    rw [h2, heta0_def]
    rw [show Real.sqrt (2 * D / (L * sigma2 * (T : ℝ))) * L * sigma2
        = Real.sqrt (2 * D / (L * sigma2 * (T : ℝ))) * (L * sigma2) by ring]
    rw [sqrt_mul_sq (2 * D / (L * sigma2 * (T : ℝ))) (L * sigma2)
        (by positivity) hA]
    congr 1
    field_simp
  rw [hopt] at hbound
  rw [← hval]
  exact hbound

/-- The measure-theoretic envelope dominates the surrogate one: it includes
    the noise variance term explicitly. -/
theorem measure_theoretic_dominates_surrogate (K T : ℕ) (zeta sigma2 drift : ℚ)
    (hs : 0 ≤ sigma2) (hK : 0 < K) (hT : 0 < T) :
    convergence_envelope K T zeta ≤
      stochasticEnvelope K T zeta sigma2 drift := by
  unfold convergence_envelope stochasticEnvelope
  rw [if_pos ⟨hK, hT⟩, if_pos ⟨hK, hT⟩]
  have hvar : 0 ≤ sigma2 / (K : ℚ) := by positivity
  have hdrift : 0 ≤ drift ^ 2 := by nlinarith
  linarith

/-- Concrete guard: measure-theoretic bound for 100 clients, 1000 rounds,
    10% heterogeneity, 1% noise, 1% drift. -/
theorem measure_theoretic_large_scale_guard :
    stochasticEnvelope 100 1000 ((1 : ℚ) / 10) ((1 : ℚ) / 100) ((1 : ℚ) / 100) <
    (5 : ℚ) / 100 := by
  norm_num [stochasticEnvelope]

end LeanFormalization
