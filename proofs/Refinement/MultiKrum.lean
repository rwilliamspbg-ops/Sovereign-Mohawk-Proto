import Mathlib
import Specification.System

/-!
# Multi-Krum / Krum Refinement: Lean Spec ↔ Go Implementation

This module documents and partially formalizes the correspondence between
`Specification.multiKrumSelectImpl` (the Lean spec, in
`Specification/System.lean`) and the real Go implementation
`MultiKrumSelect`/`MultiKrumAggregate` (`internal/multikrum.go`).

## What the two implementations compute

Both compute, for each candidate gradient, a "neighbor score" — the sum of
squared distances to its `k` (Lean) / `neighbors` (Go) nearest OTHER
gradients — and select the lowest-scoring candidate(s) as most likely
honest. This has been empirically verified to agree exactly: see
`internal/multikrum_lean_correspondence_test.go`, which recomputes the Go
side of four test vectors whose Lean-side outputs were computed via
`#eval multiKrumSelectImpl ...` and pins the expected values inline. Lean
cannot invoke or formally verify Go source directly, so this is deliberately
an *empirical* correspondence (matching concrete outputs on chosen inputs),
not a machine-checked equality theorem — the same limitation applies to any
Lean-to-non-Lean refinement claim in this repository.

## Parameter mapping: `k ↔ neighbors = n - f - 2`

Lean's `multiKrumSelectImpl` takes a raw `k : Nat` directly. Go's
`MultiKrumSelect` instead takes a Byzantine bound `f : Nat` and *derives*
`neighbors := n - f - 2` (`n` = number of candidates), only after checking
the precondition `n > 2*f + 2`. `go_neighbors_valid` and
`go_neighbors_no_clamp` below formalize, in Lean, exactly what that
precondition buys: the derived neighbor count is always a valid,
non-degenerate `k` for `multiKrumSelectImpl` — at least 1, and small enough
that `multiKrumSelectImpl`'s internal `Nat.min k (gradients.length - 1)`
clamp never fires. In other words, whenever Go's precondition holds, Go's
derived `neighbors` and Lean's `k` are the same input to the same scoring
algorithm.

## Two honest correspondence gaps (not closed by this module)

1. **Unenforced precondition.** Go refuses to run at all unless
   `n > 2f + 2` (e.g. for `n = 4`, only `f = 0` is admissible — `f = 1` is
   rejected even though naively `n - f - 2 = 1` "looks" like a valid
   neighbor count). `multiKrumSelectImpl` has no analogous precondition: it
   accepts any `k`, including values with no safe `f` behind them at all.
   The Lean spec is strictly more permissive than the Go implementation's
   safety envelope; `go_neighbors_valid`/`go_neighbors_no_clamp` show the
   Go-derived parameters always land inside what Lean accepts, but nothing
   here shows the converse, and it isn't true.
2. **`m = 1` only.** Go's `MultiKrumSelect`/`MultiKrumAggregate` pair
   implements general Multi-Krum: select the `m` lowest-scoring candidates
   and average them (`m` defaults to `neighbors`, i.e. can be `> 1`).
   `multiKrumSelectImpl` only ever returns a single gradient — it formalizes
   plain Krum (`m = 1`), not the general `m`-selection-and-average behavior
   its name suggests. The correspondence claimed and tested in this module
   is therefore scoped to Go calls with `m = 1`.
-/

namespace Refinement

open Specification

/-- Go's `MultiKrumSelect` (`internal/multikrum.go`) derives its neighbor
    count as `n - f - 2` from the Byzantine bound `f`, and requires
    `n > 2f + 2` before ever calling the scoring routine. Under that
    precondition, the derived neighbor count is a valid, non-degenerate `k`:
    at least 1 (so real neighbor-distance information is used), and
    strictly below `n - 1` (so it never needs clamping against the number
    of other candidates). -/
theorem go_neighbors_valid (n f : ℕ) (h : n > 2 * f + 2) :
    1 ≤ n - f - 2 ∧ n - f - 2 < n - 1 := by
  omega

/-- Consequence for the Lean spec: `multiKrumSelectImpl`'s internal
    `Nat.min k (gradients.length - 1)` clamp never fires when `k` is Go's
    derived neighbor count under Go's precondition. The Lean spec ends up
    using exactly the neighbor count Go computed, not a silently truncated
    version of it. -/
theorem go_neighbors_no_clamp (n f : ℕ) (h : n > 2 * f + 2) :
    Nat.min (n - f - 2) (n - 1) = n - f - 2 := by
  have hv := go_neighbors_valid n f h
  exact Nat.min_eq_left (by omega)

/-- Sanity check that the Lean spec function is deterministic (same inputs,
    same output) — a minimal precondition for any correspondence claim to
    be meaningful at all. -/
theorem multiKrumSelectImpl_deterministic (nodes : List Node) (k : Nat) :
    multiKrumSelectImpl nodes k = multiKrumSelectImpl nodes k := rfl

end Refinement
