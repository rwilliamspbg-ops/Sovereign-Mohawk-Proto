import Mathlib
import LeanFormalization.RenyiDivergenceMultivariate

/-!
# The multivariate Gaussian quadratic-form integral (affine change of variables)

`RenyiDivergenceMultivariate.lean` proves the **diagonal** Rényi divergence by
Fubini, and its docstring records that the correlated case "still needs the item-1
density and a packaged general-quadratic-form Gaussian integral". This module
supplies the second half: the packaged integral.

## What is proved

* `gaussian_integral_half_sq_1d` — the one-dimensional normalizing integral
  `∫ exp(-x²/2) dx = √(2π)`, taken from Mathlib's
  `GaussianFourier.integral_rexp_neg_mul_sq_norm`.
* `gaussian_integral_isotropic_sum` — the **isotropic** `n`-dimensional integral
  on `ι → ℝ`,
  `∫ exp(-½ ∑ᵢ xᵢ²) dx = (2π)^(card ι / 2)`.
  This is the `n`-variable Fubini factorisation of the one-dimensional result,
  the same route the diagonal Rényi theorem uses.
* `gaussian_quadratic_integral_matrix` — the **change-of-variables** step: for an
  invertible matrix `B`,
  `∫ exp(-½ ∑ᵢ ((B *ᵥ x)ᵢ)²) dx = (2π)^(card ι / 2) / |det B|`.
  The tool is `Real.map_matrix_volume_pi_eq_smul_volume_pi`, which rescales
  Lebesgue measure on `ι → ℝ` by `|det M|⁻¹`.
* `integral_gaussian_density_covariance` — the immediate corollary that the
  normalized density integrates to `1`.

Together these are exactly the missing infrastructure named in
`docs/MAJOR_WIN_PLAN.md` A.3: the `det` change-of-variables layer **and** the
packaged quadratic-form Gaussian integral.

## Scope, stated openly

* The quadratic form is written as `∑ᵢ ((B *ᵥ x)ᵢ)²`, i.e. the Gram matrix
  `Q = Bᵀ * B`. Re-expressing it as `x ⬝ᵥ Q *ᵥ x` is a finite-sum
  rearrangement that is **not** carried out here; nothing in this file states
  the correlated Rényi divergence.
* Every positive-definite covariance can be written `Q = Bᵀ * B`, but this file
  does not construct such a `B` (Mathlib has no Cholesky in this version), so
  the link from an arbitrary `Σ` to a `B` is left open.
* No Radon–Nikodym derivative or `Measure.withDensity` presentation of the
  `n`-dimensional Gaussian exists in this Mathlib; only the 1-D
  `rnDeriv_gaussianReal` does. This module therefore works with integrals of
  densities against Lebesgue measure directly.
-/

namespace LeanFormalization

open MeasureTheory
open scoped RealInnerProductSpace Matrix

variable {ι : Type*} [Fintype ι] [DecidableEq ι]

/-- The one-dimensional normalizing integral `∫ exp(-x²/2) dx = √(2π)`, from
    Mathlib's isotropic real Gaussian integral specialised to `ℝ`. -/
theorem gaussian_integral_half_sq_1d :
    ∫ x : ℝ, Real.exp (-(1 / 2) * x ^ 2) = Real.sqrt (2 * Real.pi) := by
  rw [show (∫ x : ℝ, Real.exp (-(1 / 2) * x ^ 2))
      = ∫ v : ℝ, Real.exp (-(1 / 2) * ‖v‖ ^ 2) from by
        congr 1
        ext x
        rw [Real.norm_eq_abs, sq_abs]]
  rw [GaussianFourier.integral_rexp_neg_mul_sq_norm (V := ℝ) (b := (1 / 2 : ℝ))
    (by norm_num)]
  rw [show Real.pi / (1 / 2) = 2 * Real.pi by ring]
  rw [Real.sqrt_eq_rpow, show Module.finrank ℝ ℝ = 1 from Module.finrank_self ℝ]
  norm_num

/-- **Isotropic `n`-dimensional Gaussian integral on `ι → ℝ`:**

    `∫ exp(-½ ∑ᵢ xᵢ²) dx = (2π)^(card ι / 2)`.

    Proof: the integrand factors over the coordinates (`Finset.mul_sum` plus
    `Real.exp_sum`), then `MeasureTheory.integral_fintype_prod_volume_eq_prod`
    turns the joint integral into a product of the one-dimensional
    `gaussian_integral_half_sq_1d`. -/
theorem gaussian_integral_isotropic_sum :
    ∫ (x : ι → ℝ), Real.exp (-(1 / 2) * ∑ i, (x i) ^ 2)
      = (2 * Real.pi) ^ (((Fintype.card ι : ℕ) : ℝ) / 2) := by
  rw [show (fun x : ι → ℝ => Real.exp (-(1 / 2) * ∑ i, (x i) ^ 2))
      = (fun x : ι → ℝ => ∏ i, Real.exp (-(1 / 2) * (x i) ^ 2)) from by
    funext x
    rw [Finset.mul_sum, Real.exp_sum]]
  rw [MeasureTheory.integral_fintype_prod_volume_eq_prod
        (E := fun _ : ι => ℝ)
        (f := fun i (x : ℝ) => Real.exp (-(1 / 2) * x ^ 2))]
  rw [Finset.prod_congr rfl (fun i _ => gaussian_integral_half_sq_1d)]
  rw [Finset.prod_const, Real.sqrt_eq_rpow]
  rw [← Real.rpow_natCast, ← Real.rpow_mul (by positivity)]
  congr 1
  rw [Finset.card_univ]
  ring

/-- **Quadratic-form Gaussian integral under an invertible linear map.** For an
    invertible `B : Matrix ι ι ℝ`,

    `∫ exp(-½ ∑ᵢ ((B *ᵥ x)ᵢ)²) dx = (2π)^(card ι / 2) / |det B|`.

    This is the affine change of variables: `Real.map_matrix_volume_pi_eq_smul_volume_pi`
    gives `map (toLin' B) volume = |det B|⁻¹ • volume`, and the resulting
    isotropic integral is `gaussian_integral_isotropic_sum`.

    Written with `Q = Bᵀ * B`, the exponent is `-½ x ⬝ᵥ Q *ᵥ x`; the
    rearrangement is routine finite-sum algebra and is not carried out here. -/
theorem gaussian_quadratic_integral_matrix (B : Matrix ι ι ℝ) (hB : B.det ≠ 0) :
    ∫ (x : ι → ℝ), Real.exp (-(1 / 2) * ∑ i, (Matrix.mulVec B x) i ^ 2)
      = (2 * Real.pi) ^ (((Fintype.card ι : ℕ) : ℝ) / 2) / |B.det| := by
  have hmap : Measure.map (⇑(Matrix.toLin' B)) (volume : Measure (ι → ℝ))
      = ENNReal.ofReal |B.det⁻¹| • (volume : Measure (ι → ℝ)) :=
    Real.map_matrix_volume_pi_eq_smul_volume_pi hB
  have hmeas : AEStronglyMeasurable (⇑(Matrix.toLin' B))
      (volume : Measure (ι → ℝ)) := by
    fun_prop
  have hgmeas : AEStronglyMeasurable
      (fun y : ι → ℝ => Real.exp (-(1 / 2) * ∑ i, (y i) ^ 2))
      (Measure.map (⇑(Matrix.toLin' B)) (volume : Measure (ι → ℝ))) :=
    (by fun_prop :
      Continuous (fun y : ι → ℝ => Real.exp (-(1 / 2) * ∑ i, (y i) ^ 2))).aestronglyMeasurable
  rw [show (fun x : ι → ℝ => Real.exp (-(1 / 2) * ∑ i, (Matrix.mulVec B x) i ^ 2))
      = (fun x : ι → ℝ =>
          Real.exp (-(1 / 2) * ∑ i, ((⇑(Matrix.toLin' B)) x) i ^ 2)) from by
    funext x
    rw [Matrix.toLin'_apply]]
  rw [← MeasureTheory.integral_map (φ := ⇑(Matrix.toLin' B)) hmeas.aemeasurable hgmeas]
  rw [hmap, MeasureTheory.integral_smul_measure, ENNReal.toReal_ofReal (abs_nonneg _)]
  rw [gaussian_integral_isotropic_sum, smul_eq_mul, div_eq_mul_inv, abs_inv]
  ring

/-- **The normalized density integrates to one.** Corollary of
    `gaussian_quadratic_integral_matrix`: the function
    `x ↦ |det B| / (2π)^(card ι / 2) * exp(-½ ∑ᵢ ((B *ᵥ x)ᵢ)²)`
    is a probability density on `ι → ℝ` with respect to Lebesgue measure. -/
theorem integral_gaussian_density_covariance (B : Matrix ι ι ℝ) (hB : B.det ≠ 0) :
    ∫ (x : ι → ℝ),
      (|B.det| / (2 * Real.pi) ^ (((Fintype.card ι : ℕ) : ℝ) / 2))
        * Real.exp (-(1 / 2) * ∑ i, (Matrix.mulVec B x) i ^ 2) = 1 := by
  rw [MeasureTheory.integral_const_mul, gaussian_quadratic_integral_matrix B hB]
  field_simp

end LeanFormalization
