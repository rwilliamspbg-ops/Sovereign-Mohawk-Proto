import Mathlib
import LeanFormalization.Filtration
import LeanFormalization.RobbinsSiegmund
import LeanFormalization.RobbinsSiegmundDeterministic

namespace LeanFormalization

/-!
# Supermartingale Convergence Capstone (Gap 3)

Measure-theoretic L1 instantiation of Robbins-Siegmund: a nonnegative adapted
process `V` satisfying `E[V_{t+1} | F_t] <= (1-a_t) V_t + b_t` (a.e.) with
summable `b` and divergent `sum a` has `E[V_t] -> 0`. The deterministic
core is `robbins_siegmund_deterministic`; the a.s. strengthening remains
future work (requires the full supermartingale transform).
-/

section SupermartingaleConvergence

open MeasureTheory Filter Topology

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : Measure Ω}
variable {ℱ : Filtration ℕ m}

theorem supermartingale_convergence_L1
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (a b : ℕ → ℝ)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hstep : ∀ t, ∀ᵐ ω ∂μ, μ[V (t + 1) | ℱ t] ω ≤ (1 - a t) * V t ω + b t)
    (ha : ∀ t, 0 ≤ a t ∧ a t ≤ 1)
    (hb_nonneg : ∀ t, 0 ≤ b t)
    (hsummable_b : Summable b)
    (hdivergent_a : ¬ Summable a) :
    Tendsto (fun t => ∫ ω, V t ω ∂μ) atTop (𝓝 0) := by
  let e : ℕ → ℝ := fun t => ∫ ω, V t ω ∂μ
  have he_nonneg : ∀ t, 0 ≤ e t := by
    intro t
    exact integral_nonneg (fun ω => hV_nonneg t ω)
  have hstep_e : ∀ t, e (t + 1) ≤ (1 - a t) * e t + b t := by
    intro t
    have hcond : ∫ ω, μ[V (t + 1) | ℱ t] ω ∂μ ≤
        ∫ ω, ((1 - a t) * V t ω + b t) ∂μ := by
      apply integral_mono_ae (hV_int (t + 1)).integrable (by
        have : Integrable (fun ω => (1 - a t) * V t ω + b t) μ := by
          apply Integrable.add
          · exact (hV_int t).smul (1 - a t)
          · exact integrable_const (b t)
        exact this)
      exact hstep t
    have hl : ∫ ω, μ[V (t + 1) | ℱ t] ω ∂μ = e (t + 1) := by
      simpa [e] using integral_condExp (ℱ.le t) (hV_int (t + 1))
    have hr : ∫ ω, ((1 - a t) * V t ω + b t) ∂μ =
        (1 - a t) * e t + b t := by
      have h1 : ∫ ω, (1 - a t) * V t ω ∂μ = (1 - a t) * e t := by
        simp [integral_smul, e]
      have h2 : ∫ ω, b t ∂μ = b t := by
        simp [integral_const, hμ.measure_univ]
      simp [integral_add (hV_int t).smul (1 - a t) (integrable_const (b t)), h1, h2]
    linarith [hcond, hl, hr]
  exact robbins_siegmund_deterministic e a b he_nonneg hstep_e ha hb_nonneg hsummable_b hdivergent_a


/-- Almost-sure strengthening (in progress): under the same hypotheses,
    `V_t -> 0` almost surely. The proof requires the supermartingale
    transform `M_t = V_t + sum_{k<t} a_k V_k - sum_{k<t} b_k` and an
    application of Mathlib's submartingale convergence theorem; the
    deterministic limit lemma `robbins_siegmund_limit_zero` discharges
    the final step. Tracked with `sorry` until the transform is wired. -/
theorem supermartingale_convergence_ae
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (a b : ℕ → ℝ)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hstep : ∀ t, ∀ᵐ ω ∂μ, μ[V (t + 1) | ℱ t] ω ≤ (1 - a t) * V t ω + b t)
    (ha : ∀ t, 0 ≤ a t ∧ a t ≤ 1)
    (hb_nonneg : ∀ t, 0 ≤ b t)
    (hsummable_b : Summable b)
    (hdivergent_a : ¬ Summable a) :
    ∀ᵐ ω ∂μ, Tendsto (fun t => V t ω) atTop (𝓝 0) := by
  sorry

end SupermartingaleConvergence

end LeanFormalization
