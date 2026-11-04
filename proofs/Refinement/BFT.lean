import Mathlib

/-!
# BFT Refinement: Lean Spec ↔ Go Implementation (hbft)

This module documents and formalizes the correspondence between the Lean
hierarchical BFT safety condition (Theorem1BFT: `2*f < n`) and Go's
hbft topology safety check (`NodesPerCommittee > 2*f+2`).

## Go correspondence

`internal/hbft/simulator.go` `NewSimulator`:
- rejects topologies where `NodesPerCommittee <= 2*f+2`.
- `f = hva.MaximumByzantineNodes(NodesPerCommittee)` (5/9-derived).
- local safety: `2*honest > total` (i.e. `2*f < n`).

## Gap pinned

Go's precondition (`n > 2f+2`, i.e. `2f+2 < n`) is strictly stronger than
Lean's spec (`2f < n`); the extra `+2` is MultiKrum's own `n > 2f+2`
requirement. The refinement shows Go's check implies Lean's spec safety,
but not conversely.
-/

namespace Refinement

/-- Spec (Lean) safety: 2*f < n. -/
def bftSpecSafe (n f : ℕ) : Prop := 2 * f < n

/-- Impl (Go) safety precondition: n > 2*f + 2. -/
def bftImplSafe (n f : ℕ) : Prop := 2 * f + 2 < n

/-- Refinement: Go's stricter precondition implies Lean's spec safety. -/
theorem bft_impl_refines_spec (n f : ℕ) (h : bftImplSafe n f) :
    bftSpecSafe n f := by
  unfold bftImplSafe bftSpecSafe at *
  omega

/-- Gap witness: n=4, f=1 is spec-safe (2 < 4) but impl-unsafe (4 ≮ 4). -/
theorem bft_gap_witness :
    bftSpecSafe 4 1 ∧ ¬ bftImplSafe 4 1 := by
  constructor
  · simp [bftSpecSafe]
  · simp [bftImplSafe]

/-- Concrete guard: 7 nodes, 2 byzantine — both spec-safe and impl-safe. -/
theorem bft_concrete_guard :
    bftSpecSafe 7 2 ∧ bftImplSafe 7 2 := by
  constructor <;> (simp [bftSpecSafe, bftImplSafe])

end Refinement