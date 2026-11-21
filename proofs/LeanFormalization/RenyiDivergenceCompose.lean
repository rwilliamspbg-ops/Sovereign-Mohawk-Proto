/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.RenyiDivergenceMeasure

/-!
# Rényi divergence over a product measure (composition across rounds)

`RenyiDivergenceMeasure` is the divergence of two densities with respect to a
base measure. `Theorem2RDP.renyiDivergence_product_add` proves that the
**finite-support** `RenyiDivergence` tensorizes over a product of output
distributions. This module lifts that to the measure-theoretic divergence:

> over a **product measure**, the divergence of the product densities is the
> **sum** of the divergences.

This is the building block for composition across rounds: two mechanisms whose
outputs are independent given the input induce a product measure on the joint
output, and their Rényi divergences add.

## Results

* `renyiDivergenceMeasure_prod` — the tensorization equality. Hypotheses:
  nonnegativity of the four densities (needed by `Real.mul_rpow`) and positivity
  of the two marginal integrals (needed by `Real.log_mul`).
* `gaussianRDPMeasure_two_rounds` — the consumer: two rounds of the scalar
  Gaussian mechanism have divergence `2 · (α·Δ²/(2σ²))`, obtained by composing
  `gaussianRDPBound_measure` with the tensorization equality.
* `renyiDivergenceMeasure_prod_positivity_needed` — negative control: when a
  marginal integral is `0` the equality fails.

## Honesty

* This is **independent** composition, i.e. a product measure. Adaptive
  composition — where the second mechanism's distribution depends on the first
  mechanism's realized output — is **not** covered here;
  `Theorem2RDP.RDP_adaptive_composition` covers the finite-support case with a
  worst-case bound.
* The density-nonnegativity hypotheses are required by `Real.mul_rpow`. No
  machine-checked violator is supplied for them: on the concrete instances
  checked (`norm_num` on integer exponents) the factorization happens to hold
  even for signed bases, and `Real.rpow` on a negative base at a non-integer
  exponent is not decidable by `norm_num`, so a concrete refutation would need
  the `Real.rpow` negative-base API rather than evaluation. The hypotheses are
  standard regularity conditions on densities; they are stated explicitly at
  the theorem rather than hidden.
* The multivariate Gaussian mechanism and the `(ε, δ)`-DP conversion are not
  covered.
-/

namespace LeanFormalization

open MeasureTheory

/-- The **product density** `p1 ⊗ p2`, i.e. `(p1 ⊗ p2)(x, y) = p1 x * p2 y`. -/
noncomputable def prodDensity {α β : Type*} [MeasurableSpace α] [MeasurableSpace β]
    (p1 : α → ℝ) (p2 : β → ℝ) : α × β → ℝ := fun z => p1 z.1 * p2 z.2

/-- **Rényi divergence tensorizes over a product measure.** If `p1, q1` are
    densities on `(α, μ)` and `p2, q2` densities on `(β, ν)`, all nonnegative
    and with positive Rényi integrands, then the divergence of the product
    densities w.r.t. `μ.prod ν` is the sum of the two divergences.

    This is the measure-theoretic lift of
    `Theorem2RDP.renyiDivergence_product_add`. -/
theorem renyiDivergenceMeasure_prod {α β : Type*} [MeasurableSpace α] [MeasurableSpace β]
    (p1 q1 : α → ℝ) (p2 q2 : β → ℝ) (order : ℝ) (μ : Measure α) (ν : Measure β)
    [SFinite μ] [SFinite ν]
    (hp1 : ∀ x, 0 ≤ p1 x) (hq1 : ∀ x, 0 ≤ q1 x)
    (hp2 : ∀ y, 0 ≤ p2 y) (hq2 : ∀ y, 0 ≤ q2 y)
    (hI1 : 0 < ∫ x, q1 x ^ order / p1 x ^ (order - 1) ∂μ)
    (hI2 : 0 < ∫ y, q2 y ^ order / p2 y ^ (order - 1) ∂ν) :
    RenyiDivergenceMeasure (prodDensity p1 p2) (prodDensity q1 q2) order (μ.prod ν) =
      RenyiDivergenceMeasure p1 q1 order μ + RenyiDivergenceMeasure p2 q2 order ν := by
  have hsplit : (fun z : α × β =>
        (q1 z.1 * q2 z.2) ^ order / (p1 z.1 * p2 z.2) ^ (order - 1))
      = (fun z : α × β => (q1 z.1 ^ order / p1 z.1 ^ (order - 1)) *
                            (q2 z.2 ^ order / p2 z.2 ^ (order - 1))) := by
    funext z
    rw [Real.mul_rpow (hq1 z.1) (hq2 z.2)]
    rw [Real.mul_rpow (hp1 z.1) (hp2 z.2)]
    rw [div_mul_div_comm]
  unfold RenyiDivergenceMeasure
  simp only [prodDensity]
  rw [hsplit]
  rw [MeasureTheory.integral_prod_mul
    (f := fun x => q1 x ^ order / p1 x ^ (order - 1))
    (g := fun y => q2 y ^ order / p2 y ^ (order - 1))]
  rw [Real.log_mul (ne_of_gt hI1) (ne_of_gt hI2)]
  ring

/-- **Two rounds of the scalar Gaussian mechanism.** The joint output of two
    independent rounds is a product of two normal densities, so its Rényi
    divergence is the sum of the two single-round bounds:

      `D_α(N(Δ,σ²) ⊗ N(Δ,σ²) ‖ N(0,σ²) ⊗ N(0,σ²)) = 2 · α·Δ²/(2σ²)`.

    This is the measure-theoretic composition step for the Gaussian mechanism,
    and it is the consumer that ties `renyiDivergenceMeasure_prod` to the
    derived bound `gaussianRDPBound_measure`. -/
theorem gaussianRDPMeasure_two_rounds (sigma delta alpha : ℝ)
    (hsigma : sigma ≠ 0) (halpha : alpha ≠ 1) :
    RenyiDivergenceMeasure
      (prodDensity (gaussianDensity 0 sigma) (gaussianDensity 0 sigma))
      (prodDensity (gaussianDensity delta sigma) (gaussianDensity delta sigma))
      alpha (volume.prod volume) =
      2 * (alpha * delta ^ 2 / (2 * sigma ^ 2)) := by
  have hs2 : (0 : ℝ) < sigma ^ 2 := sq_pos_of_ne_zero hsigma
  have hA : (0 : ℝ) < 2 * Real.pi * sigma ^ 2 := by nlinarith [Real.pi_pos]
  have hinv : (0 : ℝ) < 1 / Real.sqrt (2 * Real.pi * sigma ^ 2) := by positivity
  have hp0 : ∀ x : ℝ, 0 ≤ gaussianDensity 0 sigma x :=
    fun x => mul_nonneg (le_of_lt hinv) (Real.exp_nonneg _)
  have hpD : ∀ x : ℝ, 0 ≤ gaussianDensity delta sigma x :=
    fun x => mul_nonneg (le_of_lt hinv) (Real.exp_nonneg _)
  have hI : 0 < ∫ x : ℝ,
      gaussianDensity delta sigma x ^ alpha /
        gaussianDensity 0 sigma x ^ (alpha - 1) ∂volume := by
    rw [gaussianRDP_integral sigma delta alpha hsigma]
    exact Real.exp_pos _
  rw [renyiDivergenceMeasure_prod
      (p1 := gaussianDensity 0 sigma) (q1 := gaussianDensity delta sigma)
      (p2 := gaussianDensity 0 sigma) (q2 := gaussianDensity delta sigma)
      (order := alpha) (μ := volume) (ν := volume) hp0 hpD hp0 hpD hI hI]
  rw [gaussianRDPBound_measure sigma delta alpha hsigma halpha]
  ring

/-- **Negative control: the marginal-integral positivity hypotheses are
    load-bearing.** Take `p1 = 0`, `q1 = 1`, `p2 = q2 = 1` on the one-point
    space, with the Dirac measure. The first marginal integral is `0`, and the
    claimed equality would read `log 0 = log 0 + log 4`, i.e. `0 = log 4`. -/
theorem renyiDivergenceMeasure_prod_positivity_needed :
    ¬ (RenyiDivergenceMeasure (prodDensity (fun _ : Unit => (0 : ℝ)) (fun _ : Unit => (1 : ℝ)))
          (prodDensity (fun _ : Unit => (1 : ℝ)) (fun _ : Unit => (2 : ℝ)))
          2 ((Measure.dirac ()).prod (Measure.dirac ())) =
        RenyiDivergenceMeasure (fun _ : Unit => (0 : ℝ)) (fun _ : Unit => (1 : ℝ)) 2
            (Measure.dirac ()) +
          RenyiDivergenceMeasure (fun _ : Unit => (1 : ℝ)) (fun _ : Unit => (2 : ℝ)) 2
            (Measure.dirac ())) := by
  intro h
  simp only [RenyiDivergenceMeasure, prodDensity, one_div] at h
  norm_num at h
  have hpos : (0 : ℝ) < Real.log 4 := Real.log_pos (by norm_num)
  linarith

end LeanFormalization
