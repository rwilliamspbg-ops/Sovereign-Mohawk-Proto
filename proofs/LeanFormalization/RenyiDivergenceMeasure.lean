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

* `RenyiDivergenceMeasure` — the divergence of two non-negative densities with
  respect to a base measure.
* `renyiDivergenceMeasure_count` — for the counting measure on a `Fintype`, the
  integral is the finite sum.
* `renyiDivergenceMeasure_count_eq_renyiDivergence` — the finite-support
  `RenyiDivergence` of `Theorem2RDP.lean` is exactly the measure-theoretic
  divergence at the counting measure. The existing development is therefore a
  special case of the new framework, not a parallel one.
* `gaussianDensity`, `GaussianRDPHypotheses`, `gaussianRDPBound_of_hypotheses` —
  the Gaussian instantiation. The integral identity is an explicit hypothesis
  bundle (the same style as `Ed25519GroupLaws`), and the bound
  `α·Δ²/(2σ²)` is *derived* from it. Proving the identity itself is the
  remaining work, and it is named as such.

## Honesty

No claim is made that the Gaussian integral has been proved. The derivation is
conditional, and the condition is stated at the theorem. The point of this file
is to make the gap structural rather than vague: the framework exists and the
finite case is a special case of it, so the only missing piece is one integral.
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

/-- **The one missing integral.** Everything needed to derive the Gaussian
    mechanism's RDP bound, packaged as an explicit hypothesis bundle in the same
    style as `Ed25519GroupLaws`.

    For adjacent datasets differing by `delta` in one coordinate, the mechanism
    outputs `N(0, σ²)` and `N(delta, σ²)`. The Rényi divergence of order `α`
    reduces to the integral below, whose value is the completed square. Mathlib
    ships `integral_gaussian` (`∫ exp(-b·x²) dx = √(π/b)`), but not the
    shifted/completed-square form; that is the remaining lemma. -/
structure GaussianRDPHypotheses (sigma delta alpha : ℝ) where
  /-- The noise scale is positive. -/
  hsigma : 0 < sigma
  /-- The order is above 1, so the divergence is defined. -/
  halpha : 1 < alpha
  /-- **The completed-square Gaussian integral.** `p = N(0, σ²)`,
      `q = N(delta, σ²)`; the integrand is `q^α / p^(α-1)`. -/
  hintegral :
    ∫ x, (gaussianDensity delta sigma x) ^ alpha /
        (gaussianDensity 0 sigma x) ^ (alpha - 1) ∂volume =
      Real.exp (alpha * (alpha - 1) * delta ^ 2 / (2 * sigma ^ 2))

/-- **The Gaussian RDP bound, derived.** Under the explicit integral identity,
    the Gaussian mechanism's Rényi divergence of order `alpha` between
    `N(0, σ²)` and `N(delta, σ²)` is exactly `alpha * delta² / (2 σ²)` — the
    `(α, α·Δ²/(2σ²))`-RDP bound, obtained by derivation rather than asserted as
    a witness.

    The only unproved input is `GaussianRDPHypotheses.hintegral`. -/
theorem gaussianRDPBound_of_hypotheses (sigma delta alpha : ℝ)
    (h : GaussianRDPHypotheses sigma delta alpha) :
    RenyiDivergenceMeasure (gaussianDensity 0 sigma) (gaussianDensity delta sigma)
      alpha volume = alpha * delta ^ 2 / (2 * sigma ^ 2) := by
  unfold RenyiDivergenceMeasure
  rw [h.hintegral, Real.log_exp]
  have hne : alpha - 1 ≠ 0 := by have := h.halpha; linarith
  field_simp

/-- The bound is non-negative for a positive order — a sanity property that the
    existence witness in `Theorem2RDP.lean` could only assert by `positivity`. -/
theorem gaussianRDPBound_nonneg (sigma delta alpha : ℝ)
    (h : GaussianRDPHypotheses sigma delta alpha) (halpha : 0 < alpha) :
    0 ≤ alpha * delta ^ 2 / (2 * sigma ^ 2) := by
  have := h.hsigma
  positivity

end LeanFormalization
