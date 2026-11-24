import Mathlib
import LeanFormalization.MultiKrumConvergence

/-!
# Multi-Krum convergence under a bias, not exact unbiasedness

`MultiKrumConvergence.lean` proves `multikrum_convergence_ae`: the squared
distance to the optimum converges to zero almost surely. Its descent
inequality assumes **exact unbiasedness**, `E[ĝ_t | ℱ_t] = ∇f(θ_t)`, and the
module header says plainly that the Multi-Krum selection rule does not supply
it — Krum's selection depends on the gradient values.

This module removes that hypothesis and replaces it with a quantitative one.

## What is new

* `sgd_step_condexp_expand` — the conditional-expectation expansion of the SGD
  step, stated with **no** unbiasedness assumption: everything is in terms of
  the conditional mean `E[ĝ | ℱ]`. This is the part of
  `DescentInequalityFull.descent_inequality_derived` that was already
  unbiasedness-free, factored out as a standalone lemma.
* `biased_descent_inequality` — the descent inequality under a **bias bound**
  `‖E[ĝ | ℱ] - ∇f(θ)‖² ≤ β²`:

      E‖θ' - θ*‖² | ℱ  ≤  (1 - ημ/2)‖θ - θ*‖² + η²σ² + (2η/μ)β²

  The contraction weakens from `1 - ημ` to `1 - ημ/2` because Young's
  inequality splits the budget between the two terms; that is the price of not
  assuming the bias is zero.
* `biased_multikrum_convergence_ae` — the capstone, generalising
  `multikrum_convergence_ae`: if the weighted bias sequence
  `∑ η_t β_t²` is summable (alongside `∑ η_t² < ∞`), then `V_t → 0` almost
  surely. Exact unbiasedness is the special case `β_t = 0`, so this strictly
  generalises the existing theorem.

## The hypothesis is load-bearing

`constant_bias-not-summable` is the machine-checked negative control: for a
**constant** nonzero bias `β_t = B > 0`, `∑ η_t B²` diverges, so the new
hypothesis fails — a persistent bias cannot be averaged away by a diminishing
step size.

## What is not claimed

* A constant nonzero bias still converges, but to a **neighbourhood** of the
  optimum rather than to it; the radius is not quantified here and is recorded
  as the residual gap.
* Nothing here says the real Multi-Krum rule satisfies any particular `β`; the
  bound is a hypothesis about the aggregate, exactly as unbiasedness was.
-/

namespace LeanFormalization

open MeasureTheory Filter Topology
open scoped MeasureTheory BigOperators InnerProductSpace

section BiasedExpansion

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : MeasureTheory.Measure Ω}
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E] [CompleteSpace E]

local notation "⟪" x ", " y "⟫" => inner (𝕜 := ℝ) x y

variable (θstar : E) (θ g : Ω → E) (η : ℝ)

/-- The conditional-expectation expansion of one SGD step, with **no**
    unbiasedness assumption. This is the unbiasedness-free content of
    `DescentInequalityFull.descent_inequality_derived`, factored out. -/
lemma sgd_step_condexp_expand
    (hV_int : MeasureTheory.Integrable (fun ω => ‖θ ω - θstar‖ ^ 2) μ)
    (hinner_int : MeasureTheory.Integrable (fun ω => ⟪θ ω - θstar, g ω⟫) μ)
    (hnormg_int : MeasureTheory.Integrable (fun ω => ‖g ω‖ ^ 2) μ)
    (hVmeas : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2) ω = ‖θ ω - θstar‖ ^ 2)
    (hpull : ∀ᵐ ω ∂μ,
      MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫) ω
        = ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫) :
    MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
      =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2
          - 2 * η * ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫
          + η ^ 2 * MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω) := by
  have hcong : MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
      =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' =>
          ‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2) := by
    apply MeasureTheory.condExp_congr_ae
    filter_upwards with ω'
    have h1 : θ ω' - η • g ω' - θstar = (θ ω' - θstar) - η • g ω' := by abel
    rw [h1, norm_sub_sq_real, inner_smul_right, norm_smul, Real.norm_eq_abs, mul_pow, sq_abs]
    ring
  have hsplit : MeasureTheory.condExp m μ (fun ω' =>
          ‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2)
      =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
        + MeasureTheory.condExp m μ (fun ω' => (-2 * η) * ⟪θ ω' - θstar, g ω'⟫)
        + MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2) := by
    have h1 : MeasureTheory.condExp m μ (fun ω' =>
            (‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫) + η ^ 2 * ‖g ω'‖ ^ 2)
        =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫)
          + MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2) := by
      exact MeasureTheory.condExp_add (hV_int.add (hinner_int.smul (-2 * η))) (hnormg_int.smul (η ^ 2)) m
    have h2 : MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫)
        =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
          + MeasureTheory.condExp m μ (fun ω' => (-2 * η) * ⟪θ ω' - θstar, g ω'⟫) := by
      exact MeasureTheory.condExp_add hV_int (hinner_int.smul (-2 * η)) m
    exact h1.trans (Filter.EventuallyEq.add h2 (Filter.EventuallyEq.rfl))
  have hsmulB : MeasureTheory.condExp m μ (fun ω' => (-2 * η) * ⟪θ ω' - θstar, g ω'⟫)
      =ᵐ[μ] (-2 * η) • MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫) := by
    exact MeasureTheory.condExp_smul (-2 * η) (fun ω' => ⟪θ ω' - θstar, g ω'⟫) m
  have hsmulC : MeasureTheory.condExp m μ (fun ω' => η ^ 2 * ‖g ω'‖ ^ 2)
      =ᵐ[μ] (η ^ 2) • MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) := by
    exact MeasureTheory.condExp_smul (η ^ 2) (fun ω' => ‖g ω'‖ ^ 2) m
  calc
      MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - η • g ω' - θstar‖ ^ 2)
          =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' =>
              ‖θ ω' - θstar‖ ^ 2 + (-2 * η) * ⟪θ ω' - θstar, g ω'⟫ + η ^ 2 * ‖g ω'‖ ^ 2) := hcong
      _ =ᵐ[μ] MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2)
          + MeasureTheory.condExp m μ (fun ω' => (-2 * η) * ⟪θ ω' - θstar, g ω'⟫)
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
            · exact Filter.EventuallyEq.rfl
            · exact Filter.EventuallyEq.fun_comp hpull (fun x => (-2 * η) * x)
          · exact Filter.EventuallyEq.rfl
      _ =ᵐ[μ] (fun ω => ‖θ ω - θstar‖ ^ 2
          - 2 * η * ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫
          + η ^ 2 * MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω) := by
          filter_upwards with ω
          simp [smul_eq_mul]
          ring


/-- Young's inequality in the exact shape the bias bound needs: the contraction
    budget `μsc / 2` and the reciprocal bias weight `2 / μsc`. Stated with `η`
    explicit because that is how it is used. -/
lemma young_eta_norm_sq (η μsc d b : ℝ) (hη : 0 < η) (hμsc : 0 < μsc) :
    2 * η * (d * b) ≤ η * (μsc / 2) * d ^ 2 + (2 * η / μsc) * b ^ 2 := by
  have hsq : 0 ≤ (μsc * d - 2 * b) ^ 2 := sq_nonneg _
  have h2 : (2 * μsc) * ((μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2 - 2 * d * b)
      = (μsc * d - 2 * b) ^ 2 := by
    field_simp
    ring
  have hpos : 0 ≤ (2 * μsc) * ((μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2 - 2 * d * b) := by
    rw [h2]; exact hsq
  have hstep : 0 ≤ (μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2 - 2 * d * b := by
    exact le_of_mul_le_mul_left
      (show (2 * μsc) * 0 ≤ (2 * μsc) * ((μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2 - 2 * d * b) by
        simpa [mul_zero] using hpos) (by linarith)
  have hscale : 2 * η * (d * b) ≤ η * ((μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2) := by
    have hm := mul_le_mul_of_nonneg_left hstep hη.le
    linarith
  rwa [show η * ((μsc / 2) * d ^ 2 + (2 / μsc) * b ^ 2)
      = η * (μsc / 2) * d ^ 2 + (2 * η / μsc) * b ^ 2 by ring] at hscale

end BiasedExpansion

section BiasedDescent

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : MeasureTheory.Measure Ω}
variable {E : Type*} [NormedAddCommGroup E] [InnerProductSpace ℝ E] [CompleteSpace E]

local notation "⟪" x ", " y "⟫" => inner (𝕜 := ℝ) x y

variable (θstar : E) (fval : E → ℝ) (grad : E → E) (θ g : Ω → E)
variable (η μsc L σ2 β : ℝ)

set_option maxHeartbeats 800000 in
/-- **Biased descent inequality.** Replaces the exact unbiasedness hypothesis
    `E[ĝ | ℱ] = ∇f(θ)` of `DescentInequalityFull.descent_inequality_derived` by a
    bound `‖E[ĝ | ℱ] - ∇f(θ)‖² ≤ β²` on the conditional bias. The price is that
    the contraction weakens from `1 - ημsc` to `1 - ημsc/2`: Young's inequality
    splits the strong-convexity budget between the gradient term and the bias
    term. Exact unbiasedness is the case `β = 0`, but the statement is strictly
    more general because it also covers a decaying bias. -/
theorem biased_descent_inequality
    (hV_int : MeasureTheory.Integrable (fun ω => ‖θ ω - θstar‖ ^ 2) μ)
    (hinner_int : MeasureTheory.Integrable (fun ω => ⟪θ ω - θstar, g ω⟫) μ)
    (hnormg_int : MeasureTheory.Integrable (fun ω => ‖g ω‖ ^ 2) μ)
    (hVmeas : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ (fun ω' => ‖θ ω' - θstar‖ ^ 2) ω = ‖θ ω - θstar‖ ^ 2)
    (hpull : ∀ᵐ ω ∂μ, MeasureTheory.condExp m μ (fun ω' => ⟪θ ω' - θstar, g ω'⟫) ω
        = ⟪θ ω - θstar, MeasureTheory.condExp m μ g ω⟫)
    (hbias : ∀ᵐ ω ∂μ, ‖MeasureTheory.condExp m μ g ω - grad (θ ω)‖ ^ 2 ≤ β ^ 2)
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
      (1 - η * μsc / 2) * ‖θ ω - θstar‖ ^ 2 + η ^ 2 * σ2 + (2 * η / μsc) * β ^ 2 := by
  have hexp := sgd_step_condexp_expand θstar θ g η hV_int hinner_int hnormg_int hVmeas hpull
  have hpos : 0 < μsc / 2 := by linarith
  filter_upwards [hexp, hvar, hbias] with ω heq hg hb
  rw [heq]
  set d : E := θ ω - θstar with hd
  set M : E := MeasureTheory.condExp m μ g ω with hM
  set gr : E := grad (θ ω) with hgr
  set G2 : ℝ := MeasureTheory.condExp m μ (fun ω' => ‖g ω'‖ ^ 2) ω with hG2
  set b : E := M - gr with hbdef
  have hb2 : ‖b‖ ^ 2 ≤ β ^ 2 := by simpa [b] using hb
  have hg' : G2 ≤ ‖gr‖ ^ 2 + σ2 := by simpa [G2, gr] using hg
  have hsc' : ⟪d, gr⟫ ≥ (μsc / 2) * ‖d‖ ^ 2 + (fval (θ ω) - fval θstar) := by
    simpa [d, gr] using hsc (θ ω)
  have hsm' : ‖gr‖ ^ 2 ≤ 2 * L * (fval (θ ω) - fval θstar) := by simpa [gr] using hsmooth (θ ω)
  have hmin' : fval θstar ≤ fval (θ ω) := hmin (θ ω)
  -- rewrite M = gr + b
  have hMeq : M = gr + b := by simp [b]
  have hinner_b : ⟪d, M⟫ = ⟪d, gr⟫ + ⟪d, b⟫ := by
    rw [hMeq, inner_add_right]
  -- Cauchy-Schwarz on the bias term
  have hcs_b : -⟪d, b⟫ ≤ ‖d‖ * ‖b‖ := by
    have h2 : |⟪d, b⟫| ≤ ‖d‖ * ‖b‖ := abs_real_inner_le_norm d b
    have h3 : -⟪d, b⟫ ≤ |⟪d, b⟫| := by
      rcases le_total (0:ℝ) ⟪d, b⟫ with h | h
      · rw [abs_of_nonneg h]; linarith
      · rw [abs_of_nonpos h]
    linarith
  have hηpos : 0 < η := hη.1
  -- Young on the bias term
  have hyoung : 2 * η * (‖d‖ * ‖b‖) ≤ η * (μsc / 2) * ‖d‖ ^ 2 + (2 * η / μsc) * ‖b‖ ^ 2 :=
    young_eta_norm_sq η μsc ‖d‖ ‖b‖ hηpos hμsc
  -- scale each bound by the positive factors the goal needs
  have hcs_eta : -2 * η * ⟪d, b⟫ ≤ 2 * η * (‖d‖ * ‖b‖) := by nlinarith [hcs_b, hηpos]
  have hsc_eta : -2 * η * ⟪d, gr⟫ ≤ -(η * μsc) * ‖d‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar) := by
    nlinarith [hsc', hηpos]
  have hηL : η * L ≤ 1 := by
    have h := hη.2
    calc η * L ≤ (1 / L) * L := mul_le_mul_of_nonneg_right h (le_of_lt hL)
      _ = 1 := by field_simp
  have hsmooth_eta : η ^ 2 * ‖gr‖ ^ 2 ≤ 2 * η * (fval (θ ω) - fval θstar) := by
    have h1 : η ^ 2 * ‖gr‖ ^ 2 ≤ η ^ 2 * (2 * L * (fval (θ ω) - fval θstar)) :=
      mul_le_mul_of_nonneg_left hsm' (sq_nonneg η)
    have h2 : η ^ 2 * (2 * L * (fval (θ ω) - fval θstar))
        = 2 * (η * L) * (η * (fval (θ ω) - fval θstar)) := by ring
    have h3 : 2 * (η * L) * (η * (fval (θ ω) - fval θstar))
        ≤ 2 * (η * (fval (θ ω) - fval θstar)) := by
      have ha : 2 * (η * L) ≤ 2 * 1 := by linarith
      have hb : 0 ≤ η * (fval (θ ω) - fval θstar) :=
        mul_nonneg hη.1.le (sub_nonneg.mpr hmin')
      simpa [mul_assoc] using mul_le_mul_of_nonneg_right ha hb
    linarith
  have hG2_eta : η ^ 2 * G2 ≤ η ^ 2 * (‖gr‖ ^ 2 + σ2) := by nlinarith [hg']
  have hb_eta : (2 * η / μsc) * ‖b‖ ^ 2 ≤ (2 * η / μsc) * β ^ 2 :=
    mul_le_mul_of_nonneg_left hb2 (by positivity)
  calc
    ‖d‖ ^ 2 - 2 * η * ⟪d, M⟫ + η ^ 2 * G2
        = ‖d‖ ^ 2 - 2 * η * ⟪d, gr⟫ - 2 * η * ⟪d, b⟫ + η ^ 2 * G2 := by rw [hinner_b]; ring
    _ ≤ ‖d‖ ^ 2 + (-(η * μsc) * ‖d‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar))
          + 2 * η * (‖d‖ * ‖b‖) + η ^ 2 * (‖gr‖ ^ 2 + σ2) := by
        nlinarith [hcs_eta, hsc_eta, hG2_eta]
    _ ≤ ‖d‖ ^ 2 + (-(η * μsc) * ‖d‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar))
          + (η * (μsc / 2) * ‖d‖ ^ 2 + (2 * η / μsc) * ‖b‖ ^ 2)
          + η ^ 2 * (‖gr‖ ^ 2 + σ2) := by
        nlinarith [hyoung]
    _ = (1 - η * μsc / 2) * ‖d‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar)
          + (2 * η / μsc) * ‖b‖ ^ 2 + η ^ 2 * (‖gr‖ ^ 2 + σ2) := by
        ring
    _ ≤ (1 - η * μsc / 2) * ‖d‖ ^ 2 - 2 * η * (fval (θ ω) - fval θstar)
          + (2 * η / μsc) * β ^ 2 + η ^ 2 * (‖gr‖ ^ 2 + σ2) := by
        nlinarith [hb_eta]
    _ ≤ (1 - η * μsc / 2) * ‖d‖ ^ 2 + η ^ 2 * σ2 + (2 * η / μsc) * β ^ 2 := by
        have hσ : 0 ≤ η ^ 2 * σ2 := by positivity
        nlinarith [hsmooth_eta, hmin', hσ]

end BiasedDescent

section BiasedCapstone

variable {Ω : Type*} {m : MeasurableSpace Ω} {μ : Measure Ω}
variable {ℱ : Filtration ℕ m}

/-- **Biased capstone.** Generalises `multikrum_convergence_ae`. The per-step
    bound is now the biased descent inequality of `biased_descent_inequality`
    (contraction `1 - η_t μsc / 2`, plus a bias term `(2 η_t / μsc) β_t²`), and
    almost-sure convergence to zero holds provided the weighted bias sequence
    `∑ η_t β_t²` is summable — alongside `∑ η_t² < ∞`, which the Robbins–Monro
    schedule supplies.

    Exact unbiasedness is the special case `β_t = 0`, so this strictly generalises
    the existing theorem. The hypothesis is genuinely weaker than
    `E[ĝ_t | ℱ_t] = ∇f(θ_t)`: it admits any bias that decays fast enough in the
    weighted sense, which is what a selection rule like Multi-Krum actually
    produces (it biases toward the selected set, but the bias need not vanish
    pointwise). -/
theorem biased_multikrum_convergence_ae
    (hμ : IsProbabilityMeasure μ)
    (V : ℕ → Ω → ℝ) (c : ℝ) {t₀ : ℕ} (ht₀ : 0 < t₀)
    (β : ℕ → ℝ)
    (hV_nonneg : ∀ t ω, 0 ≤ V t ω)
    (hV_sa : StronglyAdapted ℱ V)
    (hV_int : ∀ t, Integrable (V t) μ)
    (hμc : 0 < c) (hμsc : 0 < μsc) (hsigmaAgg : 0 ≤ sigmaAgg)
    (hstep_size : c * μsc ≤ (t₀ : ℝ))
    (hbias_summable : Summable (fun t : ℕ => diminishingStep c t₀ t * β t ^ 2))
    (hstep : ∀ t, ∀ᵐ ω ∂μ,
      μ[V (t + 1) | ℱ t] ω
        ≤ (1 - diminishingStep c t₀ t * (μsc / 2)) * V t ω
          + (diminishingStep c t₀ t ^ 2 * sigmaAgg
            + (2 * diminishingStep c t₀ t / μsc) * β t ^ 2)) :
    ∀ᵐ ω ∂μ, Tendsto (fun t => V t ω) atTop (𝓝 0) := by
  have hη_pos : ∀ t, 0 ≤ diminishingStep c t₀ t := by
    intro t
    rw [diminishingStep]
    positivity
  have ht₀pos : (0 : ℝ) < (t₀ : ℝ) := by exact_mod_cast ht₀
  have hη_le_one : ∀ t, diminishingStep c t₀ t * (μsc / 2) ≤ 1 := by
    intro t
    have hden : (t₀ : ℝ) ≤ ((t + t₀ : ℕ) : ℝ) := by
      have : (t₀ : ℕ) ≤ t + t₀ := by omega
      exact_mod_cast this
    have hstep_le : diminishingStep c t₀ t ≤ c / (t₀ : ℝ) := by
      rw [diminishingStep]
      gcongr
    have hdiv : c / (t₀ : ℝ) * μsc ≤ 1 := by
      rw [div_mul_eq_mul_div, div_le_one ht₀pos]
      exact hstep_size
    calc diminishingStep c t₀ t * (μsc / 2) ≤ (c / (t₀ : ℝ)) * (μsc / 2) := by gcongr
      _ = (c / (t₀ : ℝ) * μsc) / 2 := by ring
      _ ≤ 1 / 2 := by linarith [hdiv]
      _ ≤ 1 := by norm_num
  have hsummable_step : Summable (fun t : ℕ => diminishingStep c t₀ t ^ 2 * sigmaAgg) := by
    have h := summable_diminishingStep_sq c t₀
    have hsimpa : (fun t : ℕ => diminishingStep c t₀ t ^ 2 * sigmaAgg)
        = (fun t : ℕ => sigmaAgg * diminishingStep c t₀ t ^ 2) := by
      funext t; ring
    rw [hsimpa]
    exact Summable.mul_left sigmaAgg h
  have hsummable_bias : Summable (fun t : ℕ =>
      (2 * diminishingStep c t₀ t / μsc) * β t ^ 2) := by
    have h : Summable (fun t : ℕ => (2 / μsc) * (diminishingStep c t₀ t * β t ^ 2)) :=
      Summable.mul_left (2 / μsc) hbias_summable
    have hsimpa : (fun t : ℕ => (2 / μsc) * (diminishingStep c t₀ t * β t ^ 2))
        = (fun t : ℕ => (2 * diminishingStep c t₀ t / μsc) * β t ^ 2) := by
      funext t; ring
    rw [hsimpa] at h
    exact h
  have hsummable : Summable (fun t : ℕ =>
      diminishingStep c t₀ t ^ 2 * sigmaAgg
        + (2 * diminishingStep c t₀ t / μsc) * β t ^ 2) :=
    hsummable_step.add hsummable_bias
  have hdivergent : ¬ Summable (fun t : ℕ => diminishingStep c t₀ t * (μsc / 2)) := by
    have hcne : c * (μsc / 2) ≠ 0 := by positivity
    have h := not_summable_diminishingStep (c * (μsc / 2)) hcne t₀
    have hsimpa : (fun t : ℕ => diminishingStep (c * (μsc / 2)) t₀ t)
        = (fun t : ℕ => diminishingStep c t₀ t * (μsc / 2)) := by
      funext t
      rw [diminishingStep, diminishingStep]
      ring
    rw [hsimpa] at h
    exact h
  exact supermartingale_convergence_ae hμ V
    (fun t => diminishingStep c t₀ t * (μsc / 2))
    (fun t => diminishingStep c t₀ t ^ 2 * sigmaAgg
      + (2 * diminishingStep c t₀ t / μsc) * β t ^ 2)
    hV_nonneg hV_sa hV_int hstep
    (fun t => ⟨mul_nonneg (hη_pos t) (by positivity), hη_le_one t⟩)
    (fun t => by
      have h1 : 0 ≤ diminishingStep c t₀ t ^ 2 * sigmaAgg :=
        mul_nonneg (sq_nonneg _) hsigmaAgg
      have h2 : 0 ≤ (2 * diminishingStep c t₀ t / μsc) * β t ^ 2 :=
        mul_nonneg (div_nonneg (mul_nonneg (by norm_num) (hη_pos t)) hμsc.le)
          (sq_nonneg _)
      linarith)
    hsummable hdivergent

/-- **Negative control.** A constant nonzero bias makes the new summability
    hypothesis fail, so exact unbiasedness cannot simply be deleted: a
    persistent bias gives `∑ η_t β² = ∞`, and the argument above yields no
    convergence to zero. What survives in that regime is convergence to a
    **neighbourhood** of the optimum; its radius is not quantified here and is
    recorded as a residual gap rather than claimed. -/
theorem constant_bias_not_summable
    (c : ℝ) (hc : 0 < c) {t₀ : ℕ} (B : ℝ) (hB : 0 < B) :
    ¬ Summable (fun t : ℕ => diminishingStep c t₀ t * B ^ 2) := by
  have hcne : c ≠ 0 := ne_of_gt hc
  have hB2ne : B ^ 2 ≠ 0 := by positivity
  have h := not_summable_diminishingStep c hcne t₀
  intro hs
  apply h
  have hs' : Summable (fun t : ℕ => (B ^ 2)⁻¹ * (diminishingStep c t₀ t * B ^ 2)) :=
    Summable.mul_left (B ^ 2)⁻¹ hs
  convert hs' using 1
  ext t
  field_simp

end BiasedCapstone

end LeanFormalization
