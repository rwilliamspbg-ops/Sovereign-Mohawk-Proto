/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.Theorem2RDP

/-!
# Measure-theoretic Rényi divergence, and the Gaussian gap pinned to one integral

`Theorem2RDP.lean` defines `RenyiDivergence` only for **finite-support**
distributions (`{α : Type*} [Fintype α] (p q : α → ℝ)`). That is enough for
list-based composition accounting, and it is the reason the Gaussian mechanism's
`(α, α/(2σ²))`-RDP bound could only ever be stated as an existence witness
(`gaussianRDPBound`): the Gaussian output distribution is continuous, so its
divergence could not even be *expressed*.

`docs/EXTERNAL_AUDIT_SCOPE.md` §6 and matrix row 2 name the two prerequisites
for closing that gap:

1. a measure-theoretic divergence `D_α(p‖q) = (1/(α-1))·log ∫ p^α q^{1-α} dμ`;
2. the completed-square Gaussian integral, with a shift/change of variables.

This file supplies prerequisite **(1)** in full, and pins prerequisite **(2)**
to a single named integral identity together with the derivation that consumes
it — so the gap is no longer "unspecified analysis" but exactly one lemma.

## What is here

* `RenyiDivergenceMeasure` — the divergence of two densities with respect to a
  base measure.
* `renyiDivergenceMeasure_count` — for the counting measure on a `Fintype`, the
  integral is the finite sum.
* `renyiDivergenceMeasure_count_eq_renyiDivergence` — the finite-support
  `RenyiDivergence` of `Theorem2RDP.lean` is exactly the measure-theoretic
  divergence at the counting measure. The existing development is therefore a
  special case of the new framework, not a parallel one.
* `gaussianIntegral_shift` — the shifted Gaussian integral
  `∫ exp(-b·(x−c)²) dx = √(π/b)`, derived from Mathlib's `integral_gaussian`
  via the translation-invariance of Lebesgue measure.
* `gaussianRDP_integrand` + `gaussianRDP_integral` — the completed-square
  identity, **proved**: for `p = N(0,σ²)`, `q = N(Δ,σ²)`,
  `∫ q^α / p^(α−1) dx = exp(α(α−1)·Δ²/(2σ²))`.
* `gaussianRDPBound_measure` — the Gaussian mechanism's Rényi divergence is
  **derived** to be `α·Δ²/(2σ²)`, unconditionally (only `σ ≠ 0` and `α ≠ 1`).

## Honesty

Both prerequisites are now met. The earlier revision of this file stated the
Gaussian integral as an explicit hypothesis bundle; it is superseded — the
integral is proved above, so `gaussianRDPBound_measure` takes no hypothesis
beyond `σ ≠ 0`, `α ≠ 1`. This closes the gap recorded in row 2 and in
`docs/EXTERNAL_AUDIT_SCOPE.md` §6: `Theorem2RDP.gaussianRDPBound` was an
existence witness, and the bound is now derived.

What is *not* claimed: this is the scalar, fixed-variance Gaussian mechanism in
the exponent-free density model. It does not model the multivariate mechanism,
the composition across rounds, or the `(ε,δ)`-DP conversion — those remain
where they were, and row 2's composition claims are unaffected.
-/

namespace LeanFormalization

open MeasureTheory

/-- The measure-theoretic Rényi divergence of order `order` between two
    densities `p` and `q` with respect to a base measure `μ`:

    `D_α(p‖q) = (1/(α-1)) · log ∫ (q^α / p^(α-1)) dμ`.

    Same convention as the finite-support `RenyiDivergence` in
    `Theorem2RDP.lean` (`q` in the numerator, `p` in the denominator), so the
    two agree on the counting measure. -/
noncomputable def RenyiDivergenceMeasure {α : Type*} [MeasurableSpace α]
    (p q : α → ℝ) (order : ℝ) (μ : Measure α) : ℝ :=
  (1 / (order - 1)) *
    Real.log (∫ x, q x ^ order / p x ^ (order - 1) ∂μ)

/-- For the counting measure on a finite type, the measure-theoretic divergence
    is the finite sum. This is the bridge that connects the new framework to the
    existing finite-support development. -/
theorem renyiDivergenceMeasure_count {α : Type*} [MeasurableSpace α]
    [MeasurableSingletonClass α] [Fintype α] (p q : α → ℝ) (order : ℝ) :
    RenyiDivergenceMeasure p q order Measure.count =
      (1 / (order - 1)) *
        Real.log (∑ x, q x ^ order / p x ^ (order - 1)) := by
  unfold RenyiDivergenceMeasure
  rw [MeasureTheory.integral_count]

/-- **The finite-support `RenyiDivergence` is a special case.** The existing
    `Theorem2RDP.RenyiDivergence`, for `1 < order`, is exactly the
    measure-theoretic divergence at the counting measure. Nothing in the old
    development needs to change; it is subsumed. -/
theorem renyiDivergenceMeasure_count_eq_renyiDivergence {α : Type*}
    [MeasurableSpace α] [MeasurableSingletonClass α] [Fintype α]
    (p q : α → ℝ) (order : ℝ) (h : 1 < order) :
    RenyiDivergenceMeasure p q order Measure.count =
      RenyiDivergence p q order := by
  rw [renyiDivergenceMeasure_count]
  unfold RenyiDivergence
  have hne : order ≠ 1 := by linarith
  have hgt : 1 < order := h
  simp [hne, hgt]

/-- The univariate normal density with mean `mean` and standard deviation
    `sigma`. -/
noncomputable def gaussianDensity (mean sigma x : ℝ) : ℝ :=
  (1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
    Real.exp (-(x - mean) ^ 2 / (2 * sigma ^ 2))

/-- **The shifted Gaussian integral.** Translation does not change total mass.
    Mathlib ships `integral_gaussian` for the centred case (`∫ exp(-b·x²) = √(π/b)`);
    this is the change-of-variables step the Gaussian RDP derivation needs, and
    it is what turns the "completed square" into a usable integral. -/
theorem gaussianIntegral_shift (b c : ℝ) :
    (∫ x : ℝ, Real.exp (-b * (x - c) ^ 2)) = Real.sqrt (Real.pi / b) := by
  have hmp : MeasurePreserving (fun x : ℝ => x - c) volume volume :=
    measurePreserving_add_right (μ := volume) (-c)
  have hsm : AEStronglyMeasurable (fun y : ℝ => Real.exp (-b * y ^ 2))
      (Measure.map (fun x : ℝ => x - c) volume) :=
    (by fun_prop : Continuous (fun y : ℝ => Real.exp (-b * y ^ 2))).aestronglyMeasurable
  have hmap := MeasureTheory.integral_map (μ := volume)
    (φ := fun x : ℝ => x - c) hmp.1.aemeasurable hsm
  rw [← hmap, hmp.2]
  exact integral_gaussian b

/-- **The Gaussian Rényi integrand, pointwise.** The ratio `q^α / p^(α-1)` of
    two normal densities with the same variance is a *shifted* normal density
    times the completed-square constant. -/
theorem gaussianRDP_integrand (sigma delta alpha x : ℝ) (hsigma : sigma ≠ 0) :
    (gaussianDensity delta sigma x) ^ alpha / (gaussianDensity 0 sigma x) ^ (alpha - 1) =
      (1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
        Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2)) *
        Real.exp (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)) := by
  have hs2 : (0 : ℝ) < sigma ^ 2 := sq_pos_of_ne_zero hsigma
  have hA : (0 : ℝ) < 2 * Real.pi * sigma ^ 2 := by nlinarith [Real.pi_pos]
  have hinv : (0 : ℝ) < 1 / Real.sqrt (2 * Real.pi * sigma ^ 2) := by positivity
  have hexp : Real.exp (-(x - delta) ^ 2 / (2 * sigma ^ 2) * alpha -
          (-(x - 0) ^ 2 / (2 * sigma ^ 2) * (alpha - 1))) =
      Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2) +
        (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2))) := by
    congr 1
    ring
  unfold gaussianDensity
  rw [Real.mul_rpow (by positivity) (by positivity),
    Real.mul_rpow (by positivity) (by positivity)]
  rw [← Real.exp_mul, ← Real.exp_mul]
  rw [← div_mul_div_comm]
  rw [← Real.rpow_sub hinv]
  have hsub : alpha - (alpha - 1) = 1 := by ring
  rw [hsub, Real.rpow_one]
  rw [← Real.exp_sub]
  rw [show -(x - delta) ^ 2 / (2 * sigma ^ 2) * alpha -
          (-(x - 0) ^ 2 / (2 * sigma ^ 2) * (alpha - 1)) =
        alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2) +
          (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)) by ring]
  rw [Real.exp_add]
  ring

/-- **The completed-square Gaussian integral, PROVED.** For `p = N(0, σ²)` and
    `q = N(delta, σ²)`,

      ∫ q^α / p^(α-1) dx = exp(α(α−1)·delta² / (2σ²)).

    This is the identity that `docs/EXTERNAL_AUDIT_SCOPE.md` §6 listed as the
    unproved prerequisite for the Gaussian RDP bound. It is derived here from
    Mathlib's `integral_gaussian` plus the shift lemma above; no hypothesis
    bundle is involved. -/
theorem gaussianRDP_integral (sigma delta alpha : ℝ) (hsigma : sigma ≠ 0) :
    (∫ x : ℝ, (gaussianDensity delta sigma x) ^ alpha /
        (gaussianDensity 0 sigma x) ^ (alpha - 1) ∂volume) =
      Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2)) := by
  rw [show (fun x : ℝ => (gaussianDensity delta sigma x) ^ alpha /
        (gaussianDensity 0 sigma x) ^ (alpha - 1))
      = (fun x : ℝ => (1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
        Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2)) *
        Real.exp (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)))
    from funext (gaussianRDP_integrand sigma delta alpha · hsigma)]
  rw [show (fun x : ℝ => (1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
        Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2)) *
        Real.exp (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)))
      = (fun x : ℝ => ((1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
        Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2))) *
        Real.exp (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)))
    from funext (fun x => by ring)]
  rw [MeasureTheory.integral_const_mul (μ := volume)
    (r := (1 / Real.sqrt (2 * Real.pi * sigma ^ 2)) *
      Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2)))
    (f := fun x : ℝ => Real.exp (-(x - alpha * delta) ^ 2 / (2 * sigma ^ 2)))]
  rw [show (fun a : ℝ => Real.exp (-(a - alpha * delta) ^ 2 / (2 * sigma ^ 2)))
      = (fun a : ℝ => Real.exp (-(1 / (2 * sigma ^ 2)) * (a - alpha * delta) ^ 2))
    from funext (fun a => by congr 1; ring)]
  rw [gaussianIntegral_shift (1 / (2 * sigma ^ 2)) (alpha * delta)]
  have hsqrt : Real.sqrt (Real.pi / (1 / (2 * sigma ^ 2))) =
      Real.sqrt (2 * Real.pi * sigma ^ 2) := by
    congr 1
    field_simp
  rw [hsqrt]
  have hA : (0 : ℝ) < 2 * Real.pi * sigma ^ 2 := by
    have : (0 : ℝ) < sigma ^ 2 := sq_pos_of_ne_zero hsigma
    nlinarith [Real.pi_pos]
  have hne : Real.sqrt (2 * Real.pi * sigma ^ 2) ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr hA)
  field_simp

/-- **The Gaussian RDP bound, now unconditional.** The Rényi divergence of
    order `alpha` between `N(0, σ²)` and `N(delta, σ²)` is exactly
    `alpha · delta² / (2σ²)` — the `(α, α·Δ²/(2σ²))`-RDP bound, obtained by
    derivation from a *proved* integral rather than asserted as a witness.

    This supersedes the existence witness `Theorem2RDP.gaussianRDPBound`, which
    could only exhibit the value without deriving it. -/
theorem gaussianRDPBound_measure (sigma delta alpha : ℝ)
    (hsigma : sigma ≠ 0) (halpha : alpha ≠ 1) :
    RenyiDivergenceMeasure (gaussianDensity 0 sigma) (gaussianDensity delta sigma)
      alpha volume = alpha * delta ^ 2 / (2 * sigma ^ 2) := by
  unfold RenyiDivergenceMeasure
  rw [gaussianRDP_integral sigma delta alpha hsigma, Real.log_exp]
  have hne : alpha - 1 ≠ 0 := sub_ne_zero.mpr halpha
  field_simp

/-- The bound is non-negative for a positive order. -/
theorem gaussianRDPBound_nonneg (sigma delta alpha : ℝ)
    (hsigma : sigma ≠ 0) (halpha : 0 < alpha) :
    0 ≤ alpha * delta ^ 2 / (2 * sigma ^ 2) := by
  have : (0 : ℝ) < sigma ^ 2 := sq_pos_of_ne_zero hsigma
  positivity

end LeanFormalization
