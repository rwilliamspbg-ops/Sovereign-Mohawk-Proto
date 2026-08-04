import Mathlib
import Specification.Privacy

/-!
# RDP Accountant Refinement: Lean Spec ↔ Go Implementation

This module documents and partially formalizes the correspondence between
`Specification.composeRDP`/`Specification.rdpAccountant` (the exact rational
additive RDP ledger) and the real Go implementation `RDPAccountant`
(`internal/rdp_accountant.go`).

## Additive ledger: empirically verified exact match

Go's `RecordStepRat`/`RecordShardStepRat` accumulate `*big.Rat` epsilons into
`TotalEpsilon` via plain addition — the same operation as `composeRDP`'s left
fold over `List ℚ`. Because both sides use exact rational arithmetic (no
floats, no rounding), the correspondence here is checked *exactly*, not just
approximately: see `internal/rdp_accountant_lean_correspondence_test.go`,
which recomputes Go's `TotalEpsilon` for step lists whose `composeRDP` value
was computed via `#eval` on the Lean side, including a case that groups the
same steps into two `RecordShardStepRat` calls instead of one flat list (an
empirical check of the same fact `composeRDP_append`/`accountant_impl_append`
below prove: composition doesn't care how steps are grouped). All cases match
exactly.

## Gap found and formalized: the (ε, δ)-DP conversion Go applies but Lean doesn't model

Go's `CheckBudget`/`GetCurrentEpsilonRat` do **not** compare the raw additive
ledger to the configured budget. They first convert RDP to standard
`(ε, δ)`-DP via the standard formula

  `ε = ε_rdp + log(1/δ) / (α - 1)`

(see `GetCurrentEpsilon`, `GetCurrentEpsilonRat`, and `CheckBudget` in
`internal/rdp_accountant.go`) and compare *that* converted value to
`MaxBudget`. `rdpToApproxDP` below formalizes this conversion as a real
function, and `rdp_budget_conversion_shift` proves exactly what it implies:
bounding the converted quantity by `budget` is equivalent to bounding the
*raw* ledger by `budget - log(1/δ)/(α-1)`, not by `budget` itself.

This means `accountant_impl_preserves_budget` (below), which bounds the raw
`composeRDP`/`accountantImpl` ledger against a `budget` parameter, does
**not** by itself establish that Go's `CheckBudget` succeeds when that same
`budget` is used as `MaxBudget` — the conversion term (strictly positive
whenever `δ < 1` and `α > 1`, Go's operating regime) eats into the margin.
This gap was previously undocumented: row 2 of
`FORMAL_TRACEABILITY_MATRIX.md` already flags "`(ε, δ)` conversion remain
roadmap work" for `Theorem2RDP.lean`, but nothing in this Refinement module
said so explicitly for the Go-facing budget theorem specifically, nor
formalized what the conversion actually does to the bound. `Real.log` is
noncomputable, so `rdpToApproxDP` cannot be numerically evaluated via
`#eval` the way `composeRDP` was for the correspondence test above — the
claim here is the formula shape and its monotonicity/shift properties, not a
pinned numeric correspondence.
-/

namespace Refinement

open Specification

def accountantSpec (steps : List ℚ) : ℚ :=
  composeRDP steps

def accountantImpl (steps : List ℚ) : ℚ :=
  rdpAccountant steps

theorem accountant_impl_refines_spec (steps : List ℚ) :
    accountantImpl steps = accountantSpec steps := by
  rfl

theorem accountant_impl_append (xs ys : List ℚ) :
    accountantImpl (xs ++ ys) = accountantImpl xs + accountantImpl ys := by
  simp [accountantImpl, rdpAccountant, composeRDP_append]

theorem accountant_impl_monotone_append (xs ys : List ℚ)
    (h_nonneg : ∀ e ∈ ys, 0 ≤ e) :
    accountantImpl xs ≤ accountantImpl (xs ++ ys) := by
  have hsum : 0 ≤ composeRDP ys := composeRDP_nonneg ys h_nonneg
  calc
    accountantImpl xs = composeRDP xs := by rfl
    _ ≤ composeRDP xs + composeRDP ys := by linarith
    _ = composeRDP (xs ++ ys) := by
      simpa [composeRDP_append] using (composeRDP_append xs ys).symm
    _ = accountantImpl (xs ++ ys) := by rfl

theorem accountant_impl_preserves_budget (steps : List ℚ) (budget : ℚ)
  (_h_nonneg : ∀ e ∈ steps, 0 ≤ e)
    (h_budget : accountantSpec steps ≤ budget) :
    accountantImpl steps ≤ budget := by
  simpa [accountantImpl, accountantSpec, rdpAccountant] using h_budget

/-- Go's RDP-to-(ε, δ)-DP conversion (`GetCurrentEpsilon`, `GetCurrentEpsilonRat`,
    `CheckBudget` in `internal/rdp_accountant.go`): `ε = ε_rdp + log(1/δ)/(α-1)`. -/
noncomputable def rdpToApproxDP (epsilonRDP alpha delta : ℝ) : ℝ :=
  epsilonRDP + Real.log (1 / delta) / (alpha - 1)

/-- The converted quantity is monotone in the raw RDP ledger — larger
    accumulated privacy loss never yields a smaller converted bound. -/
theorem rdpToApproxDP_mono (alpha delta : ℝ) :
    Monotone (fun epsilonRDP => rdpToApproxDP epsilonRDP alpha delta) := by
  intro a b hab
  unfold rdpToApproxDP
  linarith

/-- What bounding the converted quantity (what Go's `CheckBudget` actually
    checks) implies for the raw ledger (what `accountant_impl_preserves_budget`
    bounds): staying under `budget` after conversion is equivalent to staying
    under `budget - log(1/δ)/(α-1)` before conversion. `budget`, unqualified,
    is therefore Go's `MaxBudget` only for the converted quantity — using it
    directly as the `budget` argument to `accountant_impl_preserves_budget`
    overstates the raw ledger's actual safety margin by the conversion term. -/
theorem rdp_budget_conversion_shift (epsilonRDP alpha delta budget : ℝ) :
    rdpToApproxDP epsilonRDP alpha delta ≤ budget ↔
      epsilonRDP ≤ budget - Real.log (1 / delta) / (alpha - 1) := by
  unfold rdpToApproxDP
  constructor <;> intro h <;> linarith

end Refinement
