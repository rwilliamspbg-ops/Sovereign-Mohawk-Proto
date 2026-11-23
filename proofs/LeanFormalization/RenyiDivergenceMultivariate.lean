/-
# Diagonal multivariate Gaussian Rényi divergence

`RenyiDivergenceMeasure.lean` derives the **scalar** Gaussian bound
`D_α(N(Δ,σ²) ‖ N(0,σ²)) = α·Δ²/(2σ²)`. This module extends it to **any finite
number of coordinates with a diagonal covariance matrix**, i.e. a product of
independent scalar Gaussians on `ι → ℝ`:

    D_α( ∏ᵢ N(Δᵢ, σᵢ²)  ‖  ∏ᵢ N(0, σᵢ²) )  =  ∑ᵢ α·Δᵢ² / (2·σᵢ²)

## Why this is bounded, and what it is NOT

The general multivariate Gaussian with covariance `Σ` needs

1. a multivariate density with the quadratic form `exp(-½ (x-μ)ᵀ Σ⁻¹ (x-μ))`,
2. `Σ` positive definite **and** invertible, and
3. an affine change-of-variables lemma for Lebesgue measure on `ℝⁿ`
   (the Jacobian/`det` factor).

Item 3 is **available in Mathlib**; an earlier revision of this docstring named
it the obstruction, and that is now known to be wrong.
`Real.map_matrix_volume_pi_eq_smul_volume_pi`
(`Mathlib/MeasureTheory/Measure/Lebesgue/Basic.lean:411`) rescales Lebesgue
measure on `ι → ℝ` by `|det M|⁻¹` when `det M ≠ 0`,
`MeasureTheory.Measure.map_linearMap_addHaar_eq_smul_addHaar`
(`.../Lebesgue/EqHaar.lean:234`) is the Haar form, the Jacobian integral lemmas
in `Mathlib/MeasureTheory/Function/Jacobian.lean` transport integrals, and
`Matrix.PosDef.det_pos` (`Mathlib/Analysis/Matrix/PosDef.lean:85`) covers item 2.
What *is* proved here is only the **diagonal** case, where the density
factorizes into a product of scalars and Mathlib's `n`-variable Fubini
(`MeasureTheory.integral_fintype_prod_volume_eq_prod`) does the work. The
correlated case still needs the item-1 density and a packaged
general-quadratic-form Gaussian integral. The result is therefore a statement
about **independent coordinates** — a diagonal `Σ` — and the general
(correlated) case remains open and is not implied.

## Proof route

`∏ᵢ qᵢ^α / pᵢ^(α-1)` is the product of the scalar integrands, so Fubini turns
the integral into `∏ᵢ ∫ qᵢ^α/pᵢ^(α-1)`, each factor is
`exp(α(α-1)Δᵢ²/(2σᵢ²))` by the already-proved `gaussianRDP_integral`, and
`log` of the product is the sum of the exponents.
-/
import LeanFormalization.RenyiDivergenceCompose

namespace LeanFormalization

open MeasureTheory

variable {ι : Type*} [Fintype ι] [DecidableEq ι]

/-- The **product density** on a finite index type:
    `(∏ᵢ fᵢ)(x) = ∏ᵢ fᵢ(xᵢ)`. This is the density of a product measure whose
    coordinates are independent. -/
noncomputable def prodDensityM (f : ι → ℝ → ℝ) : (ι → ℝ) → ℝ :=
  fun x => ∏ i, f i (x i)

/-- The Gaussian density is nonnegative for every `σ`, including the
    degenerate `σ = 0` (where it is identically `0`). -/
theorem gaussianDensity_nonneg (mean sigma x : ℝ) :
    0 ≤ gaussianDensity mean sigma x := by
  unfold gaussianDensity
  exact mul_nonneg (div_nonneg (by norm_num) (Real.sqrt_nonneg _)) (Real.exp_nonneg _)

omit [Fintype ι] in
/-- **`(∏ f) ^ a = ∏ f ^ a` over a finset, for nonnegative `f` and real `a`.**
    Mathlib's `Real.finset_prod_rpow` is stated for `ℝ≥0`; this is the `ℝ`
    version, needed because the Gaussian densities are plain `ℝ`-valued. -/
theorem finset_prod_rpow_real (s : Finset ι) (f : ι → ℝ) (a : ℝ)
    (h : ∀ x ∈ s, 0 ≤ f x) :
    (∏ x ∈ s, f x) ^ a = ∏ x ∈ s, f x ^ a := by
  induction s using Finset.induction with
  | empty => simp
  | insert x s hx ih =>
      have hx' : 0 ≤ f x := h x (Finset.mem_insert_self x s)
      have hs' : 0 ≤ ∏ y ∈ s, f y :=
        Finset.prod_nonneg (fun y hy => h y (Finset.mem_insert_of_mem hy))
      rw [Finset.prod_insert hx, Finset.prod_insert hx,
        Real.mul_rpow hx' hs', ih (fun y hy => h y (Finset.mem_insert_of_mem hy))]

/-- **Diagonal multivariate Gaussian RDP.** For a finite index type `ι`, the
    Rényi divergence of order `alpha` between the product of `N(0, σᵢ²)` and the
    product of `N(Δᵢ, σᵢ²)`, w.r.t. Lebesgue measure on `ι → ℝ`, is the sum of
    the per-coordinate scalar bounds:

      `D_α(∏ᵢ N(Δᵢ,σᵢ²) ‖ ∏ᵢ N(0,σᵢ²)) = ∑ᵢ α·Δᵢ² / (2·σᵢ²)`.

    This is the `(α, ∑ᵢ αΔᵢ²/(2σᵢ²))`-RDP guarantee for a Gaussian mechanism with
    a **diagonal** covariance. It is derived: the per-coordinate integral is the
    already-proved `gaussianRDP_integral`, and `n`-variable Fubini factors the
    joint integral.

    **Scope, stated openly.** The covariance is **diagonal** — the coordinates
    are independent. A general positive-definite `Σ` requires an affine change
    of variables for Lebesgue measure on `ℝⁿ` (the `det` factor), which
    Mathlib provides — see the module docstring; what is still missing is the
    multivariate density and the packaged `Σ`-integral. Nothing below implies
    the correlated case. -/
theorem gaussianRDPMeasure_diagonal (σ Δ : ι → ℝ) (alpha : ℝ)
    (hσ : ∀ i, σ i ≠ 0) (hα : alpha ≠ 1) :
    RenyiDivergenceMeasure
      (prodDensityM (fun i => gaussianDensity 0 (σ i)))
      (prodDensityM (fun i => gaussianDensity (Δ i) (σ i)))
      alpha (volume : Measure (ι → ℝ)) =
      ∑ i, alpha * (Δ i) ^ 2 / (2 * (σ i) ^ 2) := by
  have hne : alpha - 1 ≠ 0 := sub_ne_zero.mpr hα
  unfold RenyiDivergenceMeasure
  have hsplit : (fun x : ι → ℝ =>
      prodDensityM (fun i => gaussianDensity (Δ i) (σ i)) x ^ alpha /
        prodDensityM (fun i => gaussianDensity 0 (σ i)) x ^ (alpha - 1))
      = (fun x : ι → ℝ => ∏ i,
          gaussianDensity (Δ i) (σ i) (x i) ^ alpha /
            gaussianDensity 0 (σ i) (x i) ^ (alpha - 1)) := by
    funext x
    rw [prodDensityM, prodDensityM]
    have hq : ∀ i ∈ (Finset.univ : Finset ι), 0 ≤ gaussianDensity (Δ i) (σ i) (x i) := by
      intro i _
      exact gaussianDensity_nonneg ..
    rw [finset_prod_rpow_real Finset.univ (fun i => gaussianDensity (Δ i) (σ i) (x i)) alpha hq]
    rw [finset_prod_rpow_real Finset.univ (fun i => gaussianDensity 0 (σ i) (x i)) (alpha - 1)
      (by intro i _; exact gaussianDensity_nonneg ..)]
    rw [← Finset.prod_div_distrib]
  rw [hsplit]
  rw [MeasureTheory.integral_fintype_prod_volume_eq_prod
    (E := fun _ : ι => ℝ)
    (f := fun i (x : ℝ) => gaussianDensity (Δ i) (σ i) x ^ alpha /
      gaussianDensity 0 (σ i) x ^ (alpha - 1))]
  have hfac : (∏ i, ∫ x : ℝ, gaussianDensity (Δ i) (σ i) x ^ alpha /
        gaussianDensity 0 (σ i) x ^ (alpha - 1))
      = ∏ i, Real.exp (alpha * (alpha - 1) * (Δ i) ^ 2 / (2 * (σ i) ^ 2)) := by
    apply Finset.prod_congr rfl
    intro i _
    rw [gaussianRDP_integral (σ i) (Δ i) alpha (hσ i)]
  rw [hfac, Real.log_prod (fun i _ => ne_of_gt (Real.exp_pos _))]
  simp_rw [Real.log_exp]
  rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro i _
  have hi : (σ i) ^ 2 ≠ 0 := pow_ne_zero 2 (hσ i)
  field_simp

/-- **Negative control: `σ = 0` is degenerate, so `hσ` is load-bearing.** At
    `σ = 0` the "density" is identically `0` — it is not a probability density
    (it does not integrate to `1`), and `gaussianRDP_integral` does not apply
    because its own `σ ≠ 0` hypothesis fails. The diagonal theorem above is
    therefore not vacuous in its variance hypothesis. -/
theorem gaussianDensity_zero_sigma (mean x : ℝ) : gaussianDensity mean 0 x = 0 := by
  unfold gaussianDensity
  simp

/-- The degenerate density really integrates to `0`, not `1`: it is not a
    probability density. (Contrast `integral_gaussian`, which gives the mass of
    the non-degenerate normal.) -/
theorem integral_gaussianDensity_zero_sigma (mean : ℝ) :
    (∫ x : ℝ, gaussianDensity mean 0 x) = 0 := by
  rw [show (fun x : ℝ => gaussianDensity mean 0 x) = (fun _ => 0) from
    funext (gaussianDensity_zero_sigma mean)]
  simp

end LeanFormalization
