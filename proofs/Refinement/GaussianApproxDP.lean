/-
# The Gaussian mechanism's `(ε, δ)`-DP conversion

`RenyiDivergenceMeasure.lean` derives the Gaussian RDP bound
`D_α(N(Δ,σ²) ‖ N(0,σ²)) = α·Δ²/(2σ²)` (matrix row 34).
`Refinement/RDPLogBound.lean` brackets the canonical conversion
`ε(δ) = ε_RDP + log(1/δ)/(α-1)` by a two-sided **rational** interval, because
`Real.log` is noncomputable in Lean (matrix row 13).

This module joins the two, which is the last named open item of soft spot 4:
the Gaussian mechanism's `(ε, δ)`-DP guarantee is now an explicit rational
interval, at the production order `α = 10` fixed by `NewRDPAccountant`.

## What is and is not claimed

* **Claimed**: for `α = 10` and a `δ` witnessed by a power-of-2 reduction
  (`2^k ≤ 1/δ < 2^(k+1)`, i.e. `r = (1/δ)/2^k ∈ [1,2)`), the converted `ε`
  with the Gaussian RDP bound substituted in is bracketed by two explicit
  rational expressions.
* **Not claimed**: an exact equality. `Real.log` is irrational-valued in
  general, so exact correspondence is the wrong claim — the repo's stated
  position in `RDPLogBound.lean`. **Not** claimed either: the general
  measure-theoretic `(ε,δ)` theorem (Hölder + change of measure on an infinite
  base measure), the general correlated multivariate Gaussian, or adaptive
  composition. Those stay open and are not implied.
-/
import LeanFormalization.RenyiDivergenceMeasure
import Refinement.RDPLogBound

namespace Refinement

open MeasureTheory

/-- The Gaussian mechanism's RDP **value** at order `α`.
    `gaussianRDPValue` proves the divergence equals
    exactly this quantity. -/
noncomputable def gaussianRDPValue (sigma d alpha : ℝ) : ℝ :=
  alpha * d ^ 2 / (2 * sigma ^ 2)

/-- The conversion's input is exactly the divergence `gaussianRDPBound_measure`
    proves, not a restatement of it: the Gaussian mechanism's Rényi divergence
    at order `α` **is** `α·Δ²/(2σ²)`. -/
theorem gaussianRDPValue_eq_divergence (sigma d alpha : ℝ) (hsigma : sigma ≠ 0)
    (halpha : alpha ≠ 1) :
    LeanFormalization.RenyiDivergenceMeasure (LeanFormalization.gaussianDensity 0 sigma)
        (LeanFormalization.gaussianDensity d sigma) alpha volume =
      gaussianRDPValue sigma d alpha :=
  LeanFormalization.gaussianRDPBound_measure sigma d alpha hsigma halpha

/-- **The Gaussian mechanism's `(ε,δ)`-DP conversion is bracketed.** At the
    production order `α = 10`, with `ε_RDP = α·Δ²/(2σ²)`, the converted value
    `ε(δ) = ε_RDP + log(1/δ)/9` lies in an explicit rational interval determined
    by the power-of-2 witness `k` for `1/δ`. The width of the interval is the
    `RDPLogBound` log-sandwich error, not a property of the Gaussian. -/
theorem gaussian_approxDP_bound (sigma d delta x r : ℝ) (k : ℕ)
    (hx_def : x = 1 / delta) (hr_def : r = x / 2 ^ k) (hr1 : 1 ≤ r) (hr2 : r < 2) :
    gaussianRDPValue sigma d 10 +
        ((k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) - (k : ℝ) / 10 ^ 10 + (1 - r⁻¹)) / 9 ≤
      rdpToApproxDP (gaussianRDPValue sigma d 10) 10 delta ∧
      rdpToApproxDP (gaussianRDPValue sigma d 10) 10 delta ≤
        gaussianRDPValue sigma d 10 +
          ((k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (k : ℝ) / 10 ^ 10 + (r - 1)) / 9 := by
  exact rdpToApproxDP_bound (gaussianRDPValue sigma d 10)
    delta x r k hx_def hr_def hr1 hr2

/-- **The usable upper bound**: the Gaussian mechanism is `(ε,δ)`-DP with `ε` at
    most `α·Δ²/(2σ²)` plus the explicit rational conversion term. -/
theorem gaussian_approxDP_upper (sigma d delta x r : ℝ) (k : ℕ)
    (hx_def : x = 1 / delta) (hr_def : r = x / 2 ^ k) (hr1 : 1 ≤ r) (hr2 : r < 2) :
    rdpToApproxDP (gaussianRDPValue sigma d 10) 10 delta ≤
      gaussianRDPValue sigma d 10 +
        ((k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (k : ℝ) / 10 ^ 10 + (r - 1)) / 9 :=
  (gaussian_approxDP_bound sigma d delta x r k hx_def hr_def hr1 hr2).2

/-- **Production instance.** `σ = 1`, `Δ = 1`, `α = 10`, `δ = 10⁻⁵`. Then
    `ε_RDP = 10·1/(2·1) = 5`, `x = 1/δ = 10⁵`, `k = 16` and
    `r = 10⁵/2¹⁶ ∈ [1,2)`, so the converted `ε` is at most
    `5 + (16·287209/414355 + 16/10¹⁰ + (r-1))/9`. -/
theorem gaussian_approxDP_typical_upper :
    rdpToApproxDP (gaussianRDPValue 1 1 10) 10 (10 ^ (-5 : ℤ) : ℝ) ≤
      (5 : ℝ) +
        ((16 : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (16 : ℝ) / 10 ^ 10 +
          ((100000 : ℝ) / 65536 - 1)) / 9 := by
  have hx : (100000 : ℝ) = 1 / (10 ^ (-5 : ℤ) : ℝ) := by norm_num
  have hr : ((100000 : ℝ) / 65536) = (100000 : ℝ) / 2 ^ 16 := by norm_num
  have hr1 : (1 : ℝ) ≤ (100000 : ℝ) / 65536 := by norm_num
  have hr2 : (100000 : ℝ) / 65536 < 2 := by norm_num
  have h5 : gaussianRDPValue 1 1 10 = 5 := by
    rw [gaussianRDPValue]
    norm_num
  rw [← h5]
  exact gaussian_approxDP_upper 1 1 (10 ^ (-5 : ℤ) : ℝ) 100000 ((100000 : ℝ) / 65536) 16
    hx hr hr1 hr2

/-- **Negative control: `δ = 0` silently collapses the conversion.** `1/0 = 0`
    and `Real.log 0 = 0`, so the converted `ε` is just `ε_RDP` — the `δ > 0`
    hypothesis is load-bearing, and the collapse is silent rather than an error.
    (This is the same `Real.log_zero` trap `RDPLogBound.lean` documents.) -/
theorem rdpToApproxDP_delta_zero (eps : ℝ) : rdpToApproxDP eps 10 0 = eps := by
  unfold rdpToApproxDP
  simp

/-- **Negative control: the conversion degrades as `δ → 0`, as it must.** The
    upper bound is monotone in `1/δ`; at `δ = 10⁻⁵` versus `δ = 10⁻³` the
    explicit rational term is larger. -/
theorem gaussian_approxDP_delta_monotone :
    (16 : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (16 : ℝ) / 10 ^ 10 +
        ((100000 : ℝ) / 65536 - 1)
      ≥ (9 : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (9 : ℝ) / 10 ^ 10 +
        ((1000 : ℝ) / 512 - 1) := by
  norm_num

end Refinement
