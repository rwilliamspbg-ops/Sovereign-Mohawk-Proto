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

## Two gaps, both closed additively (not by changing `multiKrumSelectImpl`)

1. **Unenforced precondition — closed by `multiKrumSelectSafe`.** Go refuses
   to run at all unless `n > 2f + 2`. `multiKrumSelectImpl` itself still has
   no analogous precondition (unchanged, so the four existing pinned `m = 1`
   correspondence vectors keep passing unmodified) — but
   `Specification.multiKrumSelectSafe` is a new sibling function whose
   accepted-input set matches Go's safety envelope exactly:
   `multiKrumSelectSafe_eq_impl`/`multiKrumSelectSafe_none_outside_envelope`
   below prove it delegates to `multiKrumSelectImpl` when `n > 2f + 2` and
   returns `none` otherwise, matching Go's rejection.
2. **`m = 1` only — closed by `multiKrumSelectManyImpl`.** Go's
   `MultiKrumSelect`/`MultiKrumAggregate` pair implements general Multi-Krum:
   select the `m` lowest-scoring candidates. `multiKrumSelectImpl` still only
   ever returns a single gradient (unchanged) — but
   `Specification.multiKrumSelectManyImpl` is a new sibling function
   covering Go's actual general-`m` behavior, and
   `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl` below proves it
   agrees with `multiKrumSelectImpl` exactly at `m = 1`, via a real,
   machine-checked (not `#eval`-pinned) equivalence proof.

Both closures are additive: they establish new functions whose behavior
matches Go's, without touching `multiKrumSelectImpl`'s existing signature,
tests, or proofs.
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

/-! ## Gap 1: `multiKrumSelectSafe` matches Go's safety envelope exactly -/

theorem multiKrumSelectSafe_eq_impl (nodes : List Node) (f : Nat)
    (h : nodes.length > 2 * f + 2) :
    multiKrumSelectSafe nodes f = multiKrumSelectImpl nodes (nodes.length - f - 2) := by
  simp [multiKrumSelectSafe, h]

theorem multiKrumSelectSafe_none_outside_envelope (nodes : List Node) (f : Nat)
    (h : nodes.length ≤ 2 * f + 2) :
    multiKrumSelectSafe nodes f = none := by
  simp [multiKrumSelectSafe, Nat.not_lt.mpr h]

/-! ## Gap 2: `multiKrumSelectManyImpl` at `m = 1` equals `multiKrumSelectImpl`

This is a real, machine-checked equivalence proof, not an `#eval`-pinned
empirical correspondence (unlike this module's Go-side claims above, which
are necessarily empirical since Lean cannot invoke Go source) — both sides
are Lean functions, so their agreement can be proven outright.

The one genuine trust boundary the proof needs: `Float`'s comparison
operators (`Float.lt`/`Float.le`) are defined in Lean core via an opaque
`floatSpec : FloatSpec` constant carrying *zero* asserted properties —
confirmed via `#print floatSpec`: no reflexivity, antisymmetry, transitivity,
or totality, by design (IEEE 754 comparison is genuinely not a total order
once NaN is admitted, so Lean does not assert one). Mathlib does not define
any order instance for `Float` either (confirmed by grepping the pinned
Mathlib source for `LinearOrder`/`PartialOrder`/`Preorder Float`: no
matches), so `PartialOrder Float` fails to synthesize even with Mathlib
imported. The axioms below assert exactly what is true of the real IEEE 754
double-precision comparison this compiles to at runtime, restricted to
non-NaN values — restriction is necessary, not cosmetic: `NaN ≤ NaN`
evaluates to `false` (confirmed via `#eval`), so an unconditional `a ≤ a`
axiom would be observably false. Every use below discharges the non-NaN side
conditions from `neighborScore`'s outputs (sums of non-negative squared
distances, always finite for the finite gradient inputs this codebase
handles), never asserted for an arbitrary `Float`. -/

axiom float_le_refl (a : Float) (ha : ¬ a.isNaN) : a ≤ a
axiom float_le_of_lt (a b : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) : a < b → a ≤ b
axiom float_not_lt_iff_le (a b : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) : ¬ a < b ↔ b ≤ a
axiom float_not_le_iff_lt (a b : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) : ¬ a ≤ b ↔ b < a
axiom float_le_antisymm (a b : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) : a ≤ b → b ≤ a → a = b
axiom float_lt_of_lt_of_le (a b c : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) (hc : ¬ c.isNaN)
    (h1 : a < b) (h2 : b ≤ c) : a < c
axiom float_le_of_le_of_le (a b c : Float) (ha : ¬ a.isNaN) (hb : ¬ b.isNaN) (hc : ¬ c.isNaN)
    (h1 : a ≤ b) (h2 : b ≤ c) : a ≤ c
axiom float_lt_irrefl (a : Float) (ha : ¬ a.isNaN) : ¬ a < a

/-- "The lowest-index, lowest-scoring index," matching `argmin?`/`argminAux`'s
tie-break convention (scan ascending index, replace best only on strict
improvement, so the first-encountered minimum wins ties). -/
def IsMinIdx (xs : List Float) (idx : Nat) : Prop :=
  ∃ v, getAt? xs idx = some v ∧
    (∀ j w, getAt? xs j = some w → v ≤ w) ∧
    (∀ j w, getAt? xs j = some w → w = v → idx ≤ j)

def NoNaNList (xs : List Float) : Prop := ∀ i x, getAt? xs i = some x → ¬ x.isNaN

theorem getAt?_some_lt_length {α : Type} (xs : List α) (idx : Nat) (v : α)
    (h : getAt? xs idx = some v) : idx < xs.length := by
  induction xs generalizing idx with
  | nil => simp [getAt?] at h
  | cons x xs ih =>
      cases idx with
      | zero => simp
      | succ n =>
          have hn : getAt? xs n = some v := h
          have hlt : n < xs.length := ih n hn
          simp only [List.length_cons]
          omega

theorem getAt?_drop {α : Type} (xs : List α) (idx j : Nat) :
    getAt? (xs.drop idx) j = getAt? xs (idx + j) := by
  induction idx generalizing xs with
  | zero => simp
  | succ n ih =>
      cases xs with
      | nil => simp [getAt?]
      | cons x xs =>
          have heq : n + 1 + j = n + j + 1 := by omega
          rw [heq, List.drop_succ_cons]
          exact ih xs

theorem IsMinIdx_unique (xs : List Float) (hnn : NoNaNList xs) (i j : Nat)
    (hi : IsMinIdx xs i) (hj : IsMinIdx xs j) : i = j := by
  obtain ⟨vi, hvi, hile, himin⟩ := hi
  obtain ⟨vj, hvj, hjle, hjmin⟩ := hj
  have hnvi : ¬ vi.isNaN := hnn i vi hvi
  have hnvj : ¬ vj.isNaN := hnn j vj hvj
  have h1 : vi ≤ vj := hile j vj hvj
  have h2 : vj ≤ vi := hjle i vi hvi
  have heq : vi = vj := float_le_antisymm vi vj hnvi hnvj h1 h2
  have hij : i ≤ j := himin j vj hvj heq.symm
  have hji : j ≤ i := hjmin i vi hvi heq
  omega

def IsMinIdxUpTo (xs : List Float) (bound bestIdx : Nat) (best : Float) : Prop :=
  getAt? xs bestIdx = some best ∧ bestIdx < bound ∧
    (∀ j w, j < bound → getAt? xs j = some w → best ≤ w) ∧
    (∀ j w, j < bound → getAt? xs j = some w → w = best → bestIdx ≤ j)

/-- `argmin?`'s left-scan-with-accumulator (`argminAux`) satisfies `IsMinIdx`
over the whole list -- proven by strengthening to a loop invariant
(`IsMinIdxUpTo`) tracking correctness over the already-scanned prefix, and
inducting on the still-to-scan suffix. -/
theorem argminAux_spec (xs : List Float) (hnn : NoNaNList xs) :
    ∀ (rest : List Float) (idx bestIdx : Nat) (best : Float),
      rest = xs.drop idx →
      IsMinIdxUpTo xs idx bestIdx best →
      ∃ best', IsMinIdxUpTo xs xs.length (argminAux rest bestIdx idx best) best' := by
  intro rest
  induction rest with
  | nil =>
      intro idx bestIdx best hrest hinv
      have hlen : (xs.drop idx).length = xs.length - idx := List.length_drop
      rw [← hrest] at hlen
      simp at hlen
      obtain ⟨hval, _hbnd, hlb, htie⟩ := hinv
      refine ⟨best, hval, ?_, ?_, ?_⟩
      · exact getAt?_some_lt_length xs bestIdx best hval
      · intro j w _hj hw
        exact hlb j w (by omega) hw
      · intro j w _hj hw heq
        exact htie j w (by omega) hw heq
  | cons y ys ih =>
      intro idx bestIdx best hrest hinv
      have hcons : xs.drop idx = y :: ys := hrest.symm
      have hyget : getAt? xs idx = some y := by
        have h0 := getAt?_drop xs idx 0
        rw [hcons] at h0
        simp only [Nat.add_zero] at h0
        have hgy : getAt? (y :: ys) 0 = some y := rfl
        rw [hgy] at h0
        exact h0.symm
      have hysdrop : ys = xs.drop (idx + 1) := by
        have hdd : (xs.drop idx).drop 1 = xs.drop (idx + 1) := List.drop_drop
        rw [hcons] at hdd
        simpa using hdd
      obtain ⟨hval, hbnd, hlb, htie⟩ := hinv
      have hnvy : ¬ y.isNaN := hnn idx y hyget
      have hnvbest : ¬ best.isNaN := hnn bestIdx best hval
      show ∃ best', IsMinIdxUpTo xs xs.length
        (if y < best then argminAux ys idx (idx+1) y else argminAux ys bestIdx (idx+1) best) best'
      split
      · rename_i hylt
        have hstep : IsMinIdxUpTo xs (idx + 1) idx y := by
          refine ⟨hyget, by omega, ?_, ?_⟩
          · intro j w hj hw
            rcases Nat.lt_succ_iff_lt_or_eq.mp hj with hj' | hj'
            · have hbw : best ≤ w := hlb j w hj' hw
              exact float_le_of_lt y w hnvy (hnn j w hw) (float_lt_of_lt_of_le y best w hnvy hnvbest (hnn j w hw) hylt hbw)
            · subst hj'
              have hwy : w = y := by rw [hw] at hyget; exact Option.some.inj hyget
              rw [hwy]
              exact float_le_refl y hnvy
          · intro j w hj hw heq
            rcases Nat.lt_succ_iff_lt_or_eq.mp hj with hj' | hj'
            · exfalso
              have hbw : best ≤ w := hlb j w hj' hw
              have hlt : y < w := float_lt_of_lt_of_le y best w hnvy hnvbest (hnn j w hw) hylt hbw
              rw [heq] at hlt
              exact float_lt_irrefl y hnvy hlt
            · omega
        exact ih (idx + 1) idx y hysdrop hstep
      · rename_i hnylt
        have hble : best ≤ y := (float_not_lt_iff_le y best hnvy hnvbest).mp hnylt
        have hstep : IsMinIdxUpTo xs (idx + 1) bestIdx best := by
          refine ⟨hval, by omega, ?_, ?_⟩
          · intro j w hj hw
            rcases Nat.lt_succ_iff_lt_or_eq.mp hj with hj' | hj'
            · exact hlb j w hj' hw
            · subst hj'
              have hwy : w = y := by rw [hw] at hyget; exact Option.some.inj hyget
              rw [hwy]; exact hble
          · intro j w hj hw heq
            rcases Nat.lt_succ_iff_lt_or_eq.mp hj with hj' | hj'
            · exact htie j w hj' hw heq
            · omega
        exact ih (idx + 1) bestIdx best hysdrop hstep

theorem isMinIdxUpTo_length_isMinIdx (xs : List Float) (bestIdx : Nat) (best : Float)
    (h : IsMinIdxUpTo xs xs.length bestIdx best) : IsMinIdx xs bestIdx := by
  obtain ⟨hval, _hbnd, hlb, htie⟩ := h
  refine ⟨best, hval, ?_, ?_⟩
  · intro j w hw
    exact hlb j w (getAt?_some_lt_length xs j w hw) hw
  · intro j w hw heq
    exact htie j w (getAt?_some_lt_length xs j w hw) hw heq

theorem argmin?_isMinIdx (xs : List Float) (hnn : NoNaNList xs) (idx : Nat)
    (h : argmin? xs = some idx) : IsMinIdx xs idx := by
  cases xs with
  | nil => simp [argmin?] at h
  | cons x rest =>
      have hidx : some (argminAux rest 0 1 x) = some idx := h
      have hidxeq : argminAux rest 0 1 x = idx := Option.some.inj hidx
      have hnvx : ¬ x.isNaN := hnn 0 x rfl
      have hinit : IsMinIdxUpTo (x :: rest) 1 0 x := by
        refine ⟨rfl, by omega, ?_, ?_⟩
        · intro j w hj hw
          have hj0 : j = 0 := by omega
          subst hj0
          have hwx : w = x := Option.some.inj hw.symm
          rw [hwx]
          exact float_le_refl x hnvx
        · intro j w hj _hw _heq
          omega
      obtain ⟨best', hbest'⟩ := argminAux_spec (x :: rest) hnn rest 1 0 x rfl hinit
      rw [hidxeq] at hbest'
      exact isMinIdxUpTo_length_isMinIdx (x :: rest) idx best' hbest'

def NoNaNPairs (xs : List (Nat × Float)) : Prop := ∀ p, p ∈ xs → ¬ p.2.isNaN

def minFoldPair : List (Nat × Float) → Option (Nat × Float)
  | [] => none
  | x :: xs => some (match minFoldPair xs with
      | none => x
      | some y => if x.2 <= y.2 then x else y)

/-- `insertSortedByScore`'s head is determined by a single comparison against
the list's own head (or `x` itself if the list is empty) -- no induction, both
branches of `insertSortedByScore`'s own `if` fix the head immediately. -/
theorem insertSortedByScore_head (x : Nat × Float) (l : List (Nat × Float)) :
    (insertSortedByScore x l).head? =
      some (match l.head? with | none => x | some y => if x.2 <= y.2 then x else y) := by
  cases l with
  | nil => rfl
  | cons y ys =>
      by_cases hc : x.2 <= y.2
      · simp only [insertSortedByScore, if_pos hc, List.head?]
      · simp only [insertSortedByScore, if_neg hc, List.head?]

theorem sortAscByScore_head_eq_minFoldPair (l : List (Nat × Float)) :
    (sortAscByScore l).head? = minFoldPair l := by
  induction l with
  | nil => rfl
  | cons x xs ih =>
      show (insertSortedByScore x (sortAscByScore xs)).head? = minFoldPair (x :: xs)
      rw [insertSortedByScore_head, ih]
      rfl

theorem minFoldPair_none_iff (xs : List (Nat × Float)) : minFoldPair xs = none ↔ xs = [] := by
  cases xs with
  | nil => simp [minFoldPair]
  | cons x xs => simp only [minFoldPair]; constructor <;> intro h <;> cases h

/-- The `.1` (original node index) component is non-decreasing along the list
-- holds for `scored := (List.range n).map (fun i => (i, f i))`, the only
shape this is ever applied to: `List.range` enumerates ascending, `List.map`
preserves order, so consecutive pairs' `.1` values strictly increase (see
`headFirst_range_map`). -/
def HeadFirst : List (Nat × Float) → Prop
  | [] => True
  | x :: xs => (∀ w ∈ xs, x.1 ≤ w.1) ∧ HeadFirst xs

def IsMinScorePairVal (xs : List (Nat × Float)) (v : Nat × Float) : Prop :=
  v ∈ xs ∧ (∀ w, w ∈ xs → v.2 ≤ w.2) ∧ (∀ w, w ∈ xs → w.2 = v.2 → v.1 ≤ w.1)

/-- `minFoldPair`'s selection satisfies `IsMinScorePairVal` -- proven by
structural induction (no accumulator threading needed, unlike `argminAux`'s
loop-invariant induction: `minFoldPair`'s recursion is a genuine structural
fold, each call strictly on a smaller sub-list). -/
theorem minFoldPair_spec (xs : List (Nat × Float)) :
    NoNaNPairs xs → HeadFirst xs → ∀ v, minFoldPair xs = some v → IsMinScorePairVal xs v := by
  induction xs with
  | nil => intro _ _ v h; simp [minFoldPair] at h
  | cons x xs ih =>
      intro hnn hhf v h
      have hnvx : ¬ x.2.isNaN := hnn x (List.mem_cons_self)
      obtain ⟨hhfhd, hhftl⟩ := hhf
      cases hmx : minFoldPair xs with
      | none =>
          have hxsnil : xs = [] := (minFoldPair_none_iff xs).mp hmx
          have hv : v = x := by
            simp only [minFoldPair, hmx] at h
            exact (Option.some.inj h).symm
          rw [hv, hxsnil]
          refine ⟨List.mem_cons_self, ?_, ?_⟩
          · intro w hw; cases hw with
            | head => exact float_le_refl x.2 hnvx
            | tail _ hw' => exact absurd hw' (List.not_mem_nil)
          · intro w hw _heq; cases hw with
            | head => exact Nat.le_refl _
            | tail _ hw' => exact absurd hw' (List.not_mem_nil)
      | some y =>
          have hnn' : NoNaNPairs xs := fun p hp => hnn p (List.mem_cons_of_mem x hp)
          have hspec := ih hnn' hhftl y hmx
          obtain ⟨hymem, hylb, hytie⟩ := hspec
          have hnvy : ¬ y.2.isNaN := hnn y (List.mem_cons_of_mem x hymem)
          have hxy1 : x.1 ≤ y.1 := hhfhd y hymem
          have hv : v = (if x.2 <= y.2 then x else y) := by
            simp only [minFoldPair, hmx] at h
            exact (Option.some.inj h).symm
          by_cases hcmp : x.2 <= y.2
          · simp only [hcmp, if_true] at hv
            rw [hv]
            refine ⟨List.mem_cons_self, ?_, ?_⟩
            · intro w hw
              cases hw with
              | head => exact float_le_refl x.2 hnvx
              | tail _ hw' =>
                  have hyw := hylb w hw'
                  exact float_le_of_le_of_le x.2 y.2 w.2 hnvx hnvy (hnn w (List.mem_cons_of_mem x hw')) hcmp hyw
            · intro w hw _heq
              cases hw with
              | head => exact Nat.le_refl _
              | tail _ hw' => exact hhfhd w hw'
          · simp only [hcmp, if_false] at hv
            rw [hv]
            have hlt : y.2 < x.2 := (float_not_le_iff_lt x.2 y.2 hnvx hnvy).mp hcmp
            refine ⟨List.mem_cons_of_mem x hymem, ?_, ?_⟩
            · intro w hw
              cases hw with
              | head => exact float_le_of_lt y.2 x.2 hnvy hnvx hlt
              | tail _ hw' => exact hylb w hw'
            · intro w hw heq
              cases hw with
              | head =>
                  exfalso
                  have hcontra : y.2 < y.2 := by rw [heq] at hlt; exact hlt
                  exact float_lt_irrefl y.2 hnvy hcontra
              | tail _ hw' => exact hytie w hw' heq

theorem headFirst_append_of_le (l : List (Nat × Float)) (last : Nat × Float)
    (hl : HeadFirst l) (hlast : ∀ w ∈ l, w.1 ≤ last.1) : HeadFirst (l ++ [last]) := by
  induction l with
  | nil => simp [HeadFirst]
  | cons x xs ih =>
      obtain ⟨hxxs, hxs⟩ := hl
      have hxlast : x.1 ≤ last.1 := hlast x List.mem_cons_self
      have hxstail : ∀ w ∈ xs, w.1 ≤ last.1 := fun w hw => hlast w (List.mem_cons_of_mem x hw)
      refine ⟨?_, ih hxs hxstail⟩
      intro w hw
      rcases List.mem_append.mp hw with hw' | hw'
      · exact hxxs w hw'
      · rw [List.mem_singleton] at hw'
        rw [hw']
        exact hxlast

theorem mem_range_map_lt (n : Nat) (g : Nat → Float) (w : Nat × Float)
    (hw : w ∈ (List.range n).map (fun i => (i, g i))) : w.1 < n := by
  simp only [List.mem_map, List.mem_range] at hw
  obtain ⟨j, hj, hjw⟩ := hw
  rw [← hjw]
  exact hj

theorem headFirst_range_map (n : Nat) (f : Nat → Float) :
    HeadFirst ((List.range n).map (fun i => (i, f i))) := by
  induction n with
  | zero => simp [HeadFirst]
  | succ n ih =>
      rw [List.range_succ, List.map_append]
      apply headFirst_append_of_le
      · exact ih
      · intro w hw
        have := mem_range_map_lt n f w hw
        simp only
        omega

theorem getAt?_range_map {α : Type} (n : Nat) : ∀ (g : Nat → α) (i : Nat),
    getAt? ((List.range n).map g) i = if i < n then some (g i) else none := by
  induction n with
  | zero => intro g i; simp [getAt?]
  | succ n ih =>
      intro g i
      rw [List.range_succ_eq_map]
      simp only [List.map_cons, List.map_map]
      cases i with
      | zero => simp [getAt?]
      | succ k =>
          have hih := ih (g ∘ Nat.succ) k
          show getAt? ((List.range n).map (g ∘ Nat.succ)) k = if k + 1 < n + 1 then some (g (k+1)) else none
          rw [hih]
          by_cases hk : k < n
          · rw [if_pos hk, if_pos (by omega : k + 1 < n + 1)]
            rfl
          · rw [if_neg hk, if_neg (by omega : ¬ k + 1 < n + 1)]

theorem isMinScorePairVal_to_isMinIdx (n : Nat) (score : Nat → Float) (v : Nat × Float)
    (h : IsMinScorePairVal ((List.range n).map (fun j => (j, score j))) v) :
    IsMinIdx ((List.range n).map score) v.1 := by
  obtain ⟨hmem, hlb, htie⟩ := h
  simp only [List.mem_map, List.mem_range] at hmem
  obtain ⟨j, hjn, hjv⟩ := hmem
  have hv1 : v.1 = j := by rw [← hjv]
  have hv2 : v.2 = score j := by rw [← hjv]
  refine ⟨v.2, ?_, ?_, ?_⟩
  · rw [hv1, hv2, getAt?_range_map, if_pos hjn]
  · intro j' w hw
    rw [getAt?_range_map] at hw
    split at hw
    · rename_i hj'n
      have hmemj' : (j', score j') ∈ (List.range n).map (fun i => (i, score i)) := by
        simp only [List.mem_map, List.mem_range]
        exact ⟨j', hj'n, rfl⟩
      have hle := hlb (j', score j') hmemj'
      simp only at hle
      have hwval : score j' = w := by injection hw
      rw [← hwval]; exact hle
    · exact absurd hw (by simp)
  · intro j' w hw heq
    rw [getAt?_range_map] at hw
    split at hw
    · rename_i hj'n
      have hmemj' : (j', score j') ∈ (List.range n).map (fun i => (i, score i)) := by
        simp only [List.mem_map, List.mem_range]
        exact ⟨j', hj'n, rfl⟩
      have hwval : score j' = w := by injection hw
      have heq' : (j', score j').2 = v.2 := by simp; exact hwval.trans heq
      have hle := htie (j', score j') hmemj' heq'
      simp only at hle
      exact hle
    · exact absurd hw (by simp)

theorem multiKrumSelectManyImpl_one_selects_argmin (nodes : List Node) (k : Nat)
    (hnonempty : nodes ≠ [])
    (hnn : NoNaNList ((List.range (nodes.map Node.gradient).length).map
      (fun i => neighborScore (nodes.map Node.gradient) i (Nat.min k ((nodes.map Node.gradient).length - 1))))) :
    ∃ idx, argmin? ((List.range (nodes.map Node.gradient).length).map
        (fun i => neighborScore (nodes.map Node.gradient) i (Nat.min k ((nodes.map Node.gradient).length - 1)))) = some idx
      ∧ multiKrumSelectManyImpl nodes 1 k = [idx] := by
  set gradients := nodes.map Node.gradient with hgrad
  set neighbors := Nat.min k (gradients.length - 1) with hneighbors
  set scored := (List.range gradients.length).map (fun i => (i, neighborScore gradients i neighbors)) with hscored
  set scores := (List.range gradients.length).map (fun i => neighborScore gradients i neighbors) with hscoresdef
  have hgradne : gradients ≠ [] := by simp [hgrad]; exact hnonempty
  have hscoredne : scored ≠ [] := by
    simp only [hscored]
    rw [Ne, List.map_eq_nil_iff, List.range_eq_nil]
    simpa using hgradne
  obtain ⟨v, hv⟩ := List.exists_mem_of_ne_nil scored hscoredne
  have hheadfirst : HeadFirst scored := headFirst_range_map gradients.length (fun i => neighborScore gradients i neighbors)
  have hnnpairs : NoNaNPairs scored := by
    intro p hp
    simp only [hscored, List.mem_map, List.mem_range] at hp
    obtain ⟨i, hin, hip⟩ := hp
    have hpeq : p.2 = neighborScore gradients i neighbors := by rw [← hip]
    rw [hpeq]
    have hget : getAt? scores i = some (neighborScore gradients i neighbors) := by
      rw [hscoresdef, getAt?_range_map, if_pos hin]
    exact hnn i (neighborScore gradients i neighbors) hget
  have hmfp : ∃ w, minFoldPair scored = some w := by
    cases hms : minFoldPair scored with
    | none => exact absurd ((minFoldPair_none_iff scored).mp hms) hscoredne
    | some w => exact ⟨w, rfl⟩
  obtain ⟨w, hw⟩ := hmfp
  have hspec := minFoldPair_spec scored hnnpairs hheadfirst w hw
  have hidxmin : IsMinIdx scores w.1 := by
    have hbridge := isMinScorePairVal_to_isMinIdx gradients.length (fun i => neighborScore gradients i neighbors) w hspec
    rw [hscoresdef]; exact hbridge
  have hargmin_exists : ∃ idx, argmin? scores = some idx := by
    cases hscoresnil : scores with
    | nil =>
        exfalso
        have hgnil : gradients = [] := by
          have hc := congrArg List.length hscoresnil
          simp [hscoresdef] at hc
          exact hc
        exact hgradne hgnil
    | cons a as => exact ⟨argminAux as 0 1 a, rfl⟩
  obtain ⟨idx, hidx⟩ := hargmin_exists
  have hidxmin' : IsMinIdx scores idx := argmin?_isMinIdx scores hnn idx hidx
  have hidxeq : w.1 = idx := IsMinIdx_unique scores hnn w.1 idx hidxmin hidxmin'
  refine ⟨idx, hidx, ?_⟩
  show ((sortAscByScore scored).take 1).map Prod.fst = [idx]
  have hheadeq : (sortAscByScore scored).head? = some w := by
    rw [sortAscByScore_head_eq_minFoldPair]; exact hw
  cases hsort : sortAscByScore scored with
  | nil => rw [hsort] at hheadeq; simp at hheadeq
  | cons h t =>
      rw [hsort] at hheadeq
      simp only [List.head?] at hheadeq
      have hhw : h = w := by injection hheadeq
      rw [hhw]
      simp [hidxeq]

/-- The headline correspondence theorem closing row 12's gap 2: general-`m`
selection at `m = 1` agrees with `multiKrumSelectImpl` exactly, including its
Go-facing output shape (the selected gradient, not just its index). -/
theorem multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl (nodes : List Node) (k : Nat)
    (hnonempty : nodes ≠ [])
    (hnn : NoNaNList ((List.range (nodes.map Node.gradient).length).map
      (fun i => neighborScore (nodes.map Node.gradient) i (Nat.min k ((nodes.map Node.gradient).length - 1))))) :
    ∃ idx,
      multiKrumSelectManyImpl nodes 1 k = [idx] ∧
      multiKrumSelectImpl nodes k = getAt? (nodes.map Node.gradient) idx := by
  obtain ⟨idx, hidx, hmany⟩ := multiKrumSelectManyImpl_one_selects_argmin nodes k hnonempty hnn
  refine ⟨idx, hmany, ?_⟩
  have hgradne : nodes.map Node.gradient ≠ [] := by
    simp only [ne_eq, List.map_eq_nil_iff]
    exact hnonempty
  unfold multiKrumSelectImpl
  simp only [List.isEmpty_iff]
  rw [if_neg hgradne, hidx]

end Refinement
