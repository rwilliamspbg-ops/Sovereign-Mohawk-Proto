import Mathlib
import Refinement.RDPAccountant

/-!
# Closing the RDP -> (epsilon, delta)-DP conversion gap: a computable rational bound on Real.log

`Refinement.rdpToApproxDP` (in `RDPAccountant.lean`) models Go's
`GetCurrentEpsilon`/`GetCurrentEpsilonRat`/`CheckBudget` conversion
`epsilon = epsilon_rdp + log(1/delta) / (alpha - 1)`. The traceability
matrix (row 13) had tagged this `conversion_gap_formalized_not_closed`:
`rdpToApproxDP_mono`/`rdp_budget_conversion_shift` are proven (pure
algebra), but `Real.log` is noncomputable in Lean, so unlike the rest of
that row's additive-ledger arithmetic (checked via exact `#eval`-pinned
`ℚ`/`big.Rat` correspondence against Go), nothing numerically ties the
Lean formula to what Go's `math.Log`-based float64 computation actually
produces.

This file closes that gap with a genuine, general, machine-checked
two-sided **rational bound** on `Real.log x` for any `x > 0` -- not exact
equality (`Real.log` is irrational-valued in general, so exact
correspondence is the wrong claim here, unlike the additive ledger) -- via
the standard argument-reduction technique: write `x = r * 2^k` with
`r ∈ [1, 2)`, so `log x = k * log 2 + log r`. `log 2` is bounded via
Mathlib's own `Real.log_two_near_10` (`|log 2 - 287209/414355| ≤ 1/10^10`,
already in this repo's pinned Mathlib -- reused directly, not reproved).
`log r` is bounded via the elementary near-1 inequalities
`Real.one_sub_inv_le_log_of_pos`/`Real.log_le_sub_one_of_pos`, valid for
any `r > 0` (not just `r` near 1) -- **deliberately not** a Taylor-series
remainder bound (`Real.abs_log_sub_add_sum_range_le`), which is available
in this pinned Mathlib and would give an arbitrarily tight bound, but at
the cost of needing many more terms as `r` approaches the `[1,2)` window's
edge (worst case `r -> 2`, `x := 1 - r -> -1`, exactly Mathlib's own
Taylor-remainder lemma's slow-convergence regime). This file's use case
(an RDP privacy-budget safety-margin bound, not a high-precision numeric
output) does not need that precision: the resulting bound has an absolute
width of at most ~1 in log-space regardless of `x`'s magnitude (verified
concretely below for representative delta values, where the actual width
is closer to ~0.02), which is a large, real improvement over the naive
direct bound `1 - 1/x ≤ log x ≤ x - 1` (useless for large `x`: at
`x = 1000`, that gives `[0.999, 999]` against an actual value of `~6.9`)
while avoiding Taylor-convergence risk entirely.

`k` is supplied as an explicit witness (with a trivial `2^k ≤ x < 2^(k+1)`
side condition discharged by `norm_num`/`decide` at each call site) rather
than computed by an automatic floor/log2 extraction function -- this is
still a **general** bound (works for any `x > 0`, not just specific pinned
points; a new `delta` value needs only a new witness `k`, not a new proof
of the sandwich machinery itself), just without the extra engineering of
building a computable "find k automatically" function, which this gap's
actual use (an accountant safety-margin check, not automated proof search
over arbitrary future deltas) does not need.
-/

namespace Refinement

open Real

/-- For `r ∈ [1, 2)`, a two-sided bound on `log r` via Mathlib's elementary
    near-1 log inequalities (not a Taylor-remainder bound -- see the file
    docstring for why). Valid for any `r > 0`; `hr2` is kept as an explicit
    hypothesis to document the intended usage window even though this
    particular (coarse) bound doesn't need it. -/
theorem log_residual_bound (r : ℝ) (hr1 : 1 ≤ r) (_hr2 : r < 2) :
    1 - r⁻¹ ≤ Real.log r ∧ Real.log r ≤ r - 1 := by
  have hrpos : 0 < r := lt_of_lt_of_le one_pos hr1
  exact ⟨Real.one_sub_inv_le_log_of_pos hrpos, Real.log_le_sub_one_of_pos hrpos⟩

/-- General two-sided rational bound on `Real.log x`, for any `x > 0`
    witnessed by a power-of-2 argument reduction `x = r * 2^k`,
    `r ∈ [1, 2)`. Purely rational bound expressions (via `Real.log 2`'s
    Mathlib-proven rational anchor `287209/414355 ± 1/10^10`), so both
    sides are `#eval`-computable once `k` and `r` are concrete. -/
theorem rdpLog_sandwich (x r : ℝ) (k : ℕ)
    (hr_def : r = x / 2 ^ k) (hr1 : 1 ≤ r) (hr2 : r < 2) :
    (k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) - (k : ℝ) / 10 ^ 10 + (1 - r⁻¹) ≤ Real.log x ∧
      Real.log x ≤ (k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (k : ℝ) / 10 ^ 10 + (r - 1) := by
  have hkpos : (0 : ℝ) < (2 : ℝ) ^ k := by positivity
  have hrpos : 0 < r := lt_of_lt_of_le one_pos hr1
  have hxpos : 0 < x := by
    have hxr : x = r * 2 ^ k := by rw [hr_def]; field_simp
    rw [hxr]; positivity
  have hsplit : Real.log x = (k : ℝ) * Real.log 2 + Real.log r := by
    rw [hr_def, Real.log_div hxpos.ne' hkpos.ne', Real.log_pow]; ring
  have hlog2 := Real.log_two_near_10
  rw [abs_le] at hlog2
  obtain ⟨hlog2_lo, hlog2_hi⟩ := hlog2
  obtain ⟨hlo, hhi⟩ := log_residual_bound r hr1 hr2
  have hk_nonneg : (0 : ℝ) ≤ (k : ℝ) := Nat.cast_nonneg k
  refine ⟨?_, ?_⟩
  · rw [hsplit]; nlinarith [mul_le_mul_of_nonneg_left hlog2_lo hk_nonneg]
  · rw [hsplit]; nlinarith [mul_le_mul_of_nonneg_left hlog2_hi hk_nonneg]

/-- The gap this file closes: a genuine numeric sandwich on
    `rdpToApproxDP` (Go's actual `GetCurrentEpsilon`/`CheckBudget`
    conversion) at `alpha = 10` -- the value fixed in production by
    `NewRDPAccountant` (`internal/rdp_accountant.go`) -- for any `delta`
    witnessed by a power-of-2 reduction of `1/delta`. This is what makes
    the noncomputable conversion formula checkable against Go's actual
    computed float64 output: both bound expressions are pure rational
    arithmetic once `delta`, `k`, and `r` are concrete (see
    `test/rdp_conversion_bound_test.go` for the Go-side correspondence
    check against these bounds, pinned via `#eval` below). -/
theorem rdpToApproxDP_bound (epsilonRDP delta x r : ℝ) (k : ℕ)
    (hx_def : x = 1 / delta) (hr_def : r = x / 2 ^ k) (hr1 : 1 ≤ r) (hr2 : r < 2) :
    epsilonRDP +
        ((k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) - (k : ℝ) / 10 ^ 10 + (1 - r⁻¹)) / 9 ≤
        rdpToApproxDP epsilonRDP 10 delta ∧
      rdpToApproxDP epsilonRDP 10 delta ≤
        epsilonRDP +
          ((k : ℝ) * ((287209 : ℚ) / 414355 : ℝ) + (k : ℝ) / 10 ^ 10 + (r - 1)) / 9 := by
  obtain ⟨hlo, hhi⟩ := rdpLog_sandwich x r k hr_def hr1 hr2
  unfold rdpToApproxDP
  rw [hx_def] at hlo hhi
  have h9 : (10 : ℝ) - 1 = 9 := by norm_num
  refine ⟨?_, ?_⟩ <;> rw [h9] <;> linarith

/-- Pure-`ℚ` restatement of `rdpLog_sandwich`'s bound endpoints, so
    concrete instances are `#eval`-computable (the `ℝ`-valued theorem
    above isn't -- `Real.log`/`Real`-division aren't computable even
    though the bound expressions themselves involve no `Real.log`). -/
def logLowerRat (k : ℕ) (r : ℚ) : ℚ := (k : ℚ) * (287209 / 414355) - (k : ℚ) / 10 ^ 10 + (1 - r⁻¹)

def logUpperRat (k : ℕ) (r : ℚ) : ℚ := (k : ℚ) * (287209 / 414355) + (k : ℚ) / 10 ^ 10 + (r - 1)

/-- `ℚ` restatement of `rdpToApproxDP_bound`'s endpoints at `epsilonRDP = 0`
    (the accountant's empty-ledger starting point; nonzero `epsilonRDP`
    just shifts both bounds by the same additive amount, per the theorem
    above), `#eval`-computable for pinning concrete Go-test values. -/
def epsLowerRat (k : ℕ) (r : ℚ) : ℚ := logLowerRat k r / 9

def epsUpperRat (k : ℕ) (r : ℚ) : ℚ := logUpperRat k r / 9

-- Representative delta values Go actually supports (default 1e-5, plus
-- edge values 1e-3/1e-8), each with its power-of-2 reduction witness k and
-- r = (1/delta)/2^k, verified below to sit in the required [1,2) window.
-- These #eval results are pinned as literal big.Rat constants in
-- test/rdp_conversion_bound_test.go.

-- delta = 1e-5, x = 1/delta = 100000, k = 16 (2^16 = 65536 <= 100000 < 2^17 = 131072)
example : (2:ℚ) ^ 16 ≤ (100000 : ℚ) ∧ (100000 : ℚ) < 2 ^ 17 := by norm_num
#eval (epsLowerRat 16 (100000 / 65536 : ℚ), epsUpperRat 16 (100000 / 65536 : ℚ))
#eval ((epsLowerRat 16 (100000 / 65536 : ℚ) : Float), (epsUpperRat 16 (100000 / 65536 : ℚ) : Float))

-- delta = 1e-3, x = 1000, k = 9 (2^9 = 512 <= 1000 < 2^10 = 1024)
example : (2:ℚ) ^ 9 ≤ (1000 : ℚ) ∧ (1000 : ℚ) < 2 ^ 10 := by norm_num
#eval ((epsLowerRat 9 (1000 / 512 : ℚ) : Float), (epsUpperRat 9 (1000 / 512 : ℚ) : Float))

-- delta = 1e-8, x = 100000000, k = 26 (2^26 = 67108864 <= 1e8 < 2^27 = 134217728)
example : (2:ℚ) ^ 26 ≤ (100000000 : ℚ) ∧ (100000000 : ℚ) < 2 ^ 27 := by norm_num
#eval ((epsLowerRat 26 (100000000 / 67108864 : ℚ) : Float),
  (epsUpperRat 26 (100000000 / 67108864 : ℚ) : Float))

end Refinement
