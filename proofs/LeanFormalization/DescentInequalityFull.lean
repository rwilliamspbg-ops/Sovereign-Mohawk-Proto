import Mathlib
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Analysis.InnerProductSpace.Dual
import Mathlib.MeasureTheory.Function.ConditionalExpectation.Basic
import Mathlib.MeasureTheory.Function.ConditionalExpectation.PullOut
import LeanFormalization.Common

namespace LeanFormalization

section DescentInequalityDerivation

open scoped MeasureTheory
open scoped InnerProductSpace

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : MeasureTheory.Measure Ω}
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E] [CompleteSpace E]

local notation "⟪" x ", " y "⟫" => inner (𝕜 := ℝ) x y

variable (θstar : E)
variable (fval : E → ℝ) (grad : E → E)

variable (θ : Ω → E) (g : Ω → E)
variable (η μsc L σ2 : ℝ)


lemma sgd_step_expand (ω : Ω) :
    ‖θ ω - η • g ω - θstar‖ ^ 2 =
    ‖θ ω - θstar‖ ^ 2 - 2 * η * ⟪θ ω - θstar, g ω⟫ + η ^ 2 * ‖g ω‖ ^ 2 := by
  have h1 : θ ω - η • g ω - θstar = (θ ω - θstar) - η • g ω := by
    simp [sub_eq_add_neg, smul_sub]
  rw [h1, norm_sub_sq_real]
  have hinner : ⟪θ ω - θstar, η • g ω⟫ = η * ⟪θ ω - θstar, g ω⟫ := by
    exact inner_smul_right (θ ω - θstar) (g ω) η
  have hnorm : ‖η • g ω‖ ^ 2 = η ^ 2 * ‖g ω‖ ^ 2 := by
    rw [norm_smul, mul_pow, sq_abs]
  rw [hinner, hnorm]
  ring

theorem descent_inequality_derived
    (hV_int : MeasureTheory.Integrable (fun ω => ‖θ ω - θstar‖ ^ 2) μ)
    (hinner_int : MeasureTheory.Integrable (fun ω => ⟪θ ω - θstar, g ω⟫) μ)
    (hnormg_int : MeasureTheory.Integrable (fun ω => ‖g ω‖ ^ 2) μ)
    (hVmeas : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2) ω = ‖θ ω - θstar‖ ^ 2)
    (hpull : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫) ω = ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫)
    (hunbias : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ g ω = grad (θ ω))
    (hvar : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω ≤ ‖grad (θ ω)‖ ^ 2 + σ2)
    (hsc : ∀ x : E, ⟪x - θstar, grad x⟫ ≥ (μsc / 2) * ‖x - θstar‖ ^ 2 + (fval x - fval θstar))
    (hsmooth : ∀ x : E, ‖grad x‖ ^ 2 ≤ 2 * L * (fval x - fval θstar))
    (hmin : ∀ x : E, fval θstar ≤ fval x)
    (hη : 0 < η ∧ η ≤ 1 / L)
    (hμsc : 0 < μsc)
    (hL : 0 < L)
    (hσ2 : 0 ≤ σ2) :
    ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2) ω ≤
      (1 - η * μsc) * ‖θ ω - θstar‖ ^ 2 + η ^ 2 * σ2 := by
  have hsplit : MeasureTheory.condExp m μ (fun ω' =>
          ‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2)
      =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
        + MeasureTheory.condExp m μ (fun ω' => -2 * η * ⟪θ ω' - θstar, g ω'⟫)
        + MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2) := by
    have h1 : MeasureTheory.condExp m μ (fun ω' =>
            (‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫) + η ^ 2 * ‖g ω'‖ ^ 2)
        =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫)
          + MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2) := by
      apply MeasureTheory.condExp_add
      · apply MeasureTheory.Integrable.sub
        · exact hV_int
        · exact hinner_int.smul (2 * η)
      · exact hnormg_int.smul (η ^ 2)
    have h2 : MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫)
        =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
          + MeasureTheory.condExp m μ (fun ω' => -2 * η * ⟪θ ω' - θstar, g ω'⟫) := by
      apply MeasureTheory.condExp_add
      · exact hV_int
      · exact hinner_int.smul (-2 * η)
    exact h1.trans (Filter.EventuallyEq.add h2 (Filter.EventuallyEq.refl _))
  have hsmulB : MeasureTheory.condExp m μ (fun ω' => -2 * η * ⟪θ ω' - θstar, g ω'⟫)
      =ᵐ[μ] (-2 * η) • MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫) := by
    exact MeasureTheory.condExp_smul (-2 * η) (fun ω' => ⟪θ ω' - θstar, g ω'⟫) m
  have hsmulC : MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2)
      =ᵐ[μ] (η ^ 2) • MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) := by
    exact MeasureTheory.condExp_smul (η ^ 2) (fun ω' => ‖g ω'‖ ^ 2) m
  have hcong : MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
      =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' =>
          ‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2) := by
    apply MeasureTheory.condExp_congr_ae
    filter_upwards with ω'
    exact sgd_step_expand θstar θ g η ω'
  have hexp : MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
      =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2
          - 2 * η * ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫
          + η ^ 2 * MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω) := by
    calc
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
          =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' =>
              ‖θ ω' - θstar‖ ^ 2 - 2 * η * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2) := hcong
      _ =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
          + MeasureTheory.condExp m μ (fun ω' => -2 * η * ⟪θ ω' - θstar, g ω'⟫)
          + MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2) := hsplit
      _ =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2)
          + (-2 * η) • MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫)
          + (η ^ 2) • MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) := by
          apply Filter.EventuallyEq.add
          · apply Filter.EventuallyEq.add
            · exact hVmeas
            · exact hsmulB
          · exact hsmulC
      _ =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2)
          + (-2 * η) • (fun ω => ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫)
          + (η ^ 2) • MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) := by
          apply Filter.EventuallyEq.add
          · apply Filter.EventuallyEq.add
            · exact Filter.EventuallyEq.refl _
            · exact Filter.EventuallyEq.smul (-2 * η) hpull
          · exact Filter.EventuallyEq.refl _
      _ =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2
          - 2 * η * ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫
          + η ^ 2 * MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω) := by
          filter_upwards with ω
          simp [smul_eq_mul]
  have hexp2 : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2) ω ≤
      ‖θ ω - θstar‖ ^ 2
      - 2 * η * ⟪θ ω - θstar, grad (θ ω)⟫
      + η ^ 2 * (‖grad (θ ω)‖ ^ 2 + σ2) := by
    filter_upwards [hexp, hunbias, hvar] with ω he hu hv
    rw [he, hu]
    have hη2 : 0 ≤ η ^ 2 := sq_nonneg η
    have := mul_le_mul_of_nonneg_left hv hη2
    linarith [this]
  have hfinal : ∀ᵐ ω ∂μ,
      ‖θ ω - θstar‖ ^ 2
      - 2 * η * ⟪θ ω - θstar, grad (θ ω)⟫
      + η ^ 2 * (‖grad (θ ω)‖ ^ 2 + σ2) ≤
      (1 - η * μsc) * ‖θ ω - θstar‖ ^ 2 + η ^ 2 * σ2 := by
    filter_upwards with ω
    have hfnonneg : 0 ≤ fval (θ ω) - fval θstar := by
      have := hmin (θ ω); linarith
    have hscw : ⟪θ ω - θstar, grad (θ ω)⟫ ≥ (μsc / 2) * ‖θ ω - θstar‖ ^ 2 + (fval (θ ω) - fval θstar) := hsc (θ ω)
    have hsmw : ‖grad (θ ω)‖ ^ 2 ≤ 2 * L * (fval (θ ω) - fval θstar) := hsmooth (θ ω)
    have hc : -2 * η ≤ 0 := by linarith [hη.1]
    have h1 : -2 * η * ⟪θ ω - θstar, grad (θ ω)⟫ ≤
        -η * μsc * ‖θ ω - θstar‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar) := by
      have := mul_le_mul_of_nonpos_left hscw hc
      have hexp_rhs : -2 * η * ((μsc / 2) * ‖θ ω - θstar‖ ^ 2 + (fval (θ ω) - fval θstar)) =
          -η * μsc * ‖θ ω - θstar‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar) := by ring
      linarith [this, hexp_rhs]
    have h2 : η ^ 2 * ‖grad (θ ω)‖ ^ 2 ≤ 2 * η ^ 2 * L * (fval (θ ω) - fval θstar) := by
      have hc2 : 0 ≤ η ^ 2 := sq_nonneg η
      exact mul_le_mul_of_nonneg_left hsmw hc2
    have hηL : η * L ≤ 1 := by nlinarith [hη.2, hL]
    have hcoef : -2 * η + 2 * η ^ 2 * L ≤ 0 := by nlinarith [hη.1, hηL]
    have hprod : (-2 * η + 2 * η ^ 2 * L) * (fval (θ ω) - fval θstar) ≤ 0 := by
      nlinarith [hcoef, hfnonneg]
    have hsum : ‖θ ω - θstar‖ ^ 2 - 2 * η * ⟪θ ω - θstar, grad (θ ω)⟫ + η ^ 2 * (‖grad (θ ω)‖ ^ 2 + σ2) ≤
        (1 - η * μsc) * ‖θ ω - θstar‖ ^ 2 + (-2 * η + 2 * η ^ 2 * L) * (fval (θ ω) - fval θstar) + η ^ 2 * σ2 := by
      linarith [h1, h2]
    exact le_trans hsum (by linarith [hprod])
  filter_upwards [hexp2, hfinal] with ω he hf
  exact le_trans he hf

end DescentInequalityDerivation

end LeanFormalization
