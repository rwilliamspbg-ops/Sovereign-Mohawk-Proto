-- Theorem1BFT.lean
--
-- Formalizes the concrete claim in proofs/bft_resilience.md: a tier whose
-- Byzantine count satisfies the 5/9 profile guard (9f < 5n) has a Byzantine
-- fraction strictly below 5/9 (~55.5%). This is a real, checked arithmetic
-- consequence of the guard for a *given* tier.
--
-- It is deliberately NOT a claim that recursive hierarchical composition of
-- per-tier honest-majority (f < n/2) filtering converges to a 55.5% global
-- bound in general — bft_resilience.md is explicit that the compositional
-- honest-majority theorem and the concrete 5/9 profile check are two
-- distinct results that should not be conflated. A previous version of this
-- file stated the 555/1000 figure as an unconditional existential
-- (`∃ f_global, f_global ≥ 555/1000`, provable for any input by picking that
-- witness) — that proved nothing about the actual system and has been
-- replaced below with guard-dependent theorems.
--
-- The compositional question was subsequently attempted for real (see the
-- "Hierarchical composition" section near the end of this file) and found
-- FALSE: a machine-checked counterexample (`hierarchical_composition_counterexample`)
-- shows a weighted local honest-majority guard holding at every tier does
-- not bound the true global Byzantine leaf fraction below 1/2, for any
-- choice of per-level threshold. See bft_resilience.md's "Correction"
-- section and that theorem's own doc comment for the full argument and
-- what a true (necessarily probabilistic) version would need.

import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- A tier's Byzantine fraction is below 1/2 whenever its Byzantine count is
    less than half its size (the classical honest-majority guard). -/
theorem tier_byzantine_fraction_bound (c f : ℕ) (hc : 0 < c) (h : 2 * f < c) :
    (f : ℚ) / c < (1 : ℚ) / 2 := by
  have hcQ : (0 : ℚ) < c := by exact_mod_cast hc
  rw [div_lt_div_iff₀ hcQ (by norm_num)]
  have h' : (2 : ℚ) * f < c := by exact_mod_cast h
  linarith

/-- The 5/9 profile guard: if `9 * f < 5 * n`, the Byzantine fraction is
    strictly below 5/9 ≈ 55.5%. -/
theorem theorem1_five_ninths_guard (n f : ℕ) (hn : 0 < n) (h : 9 * f < 5 * n) :
    (f : ℚ) / n < (5 : ℚ) / 9 := by
  have hnQ : (0 : ℚ) < n := by exact_mod_cast hn
  rw [div_lt_div_iff₀ hnQ (by norm_num)]
  have h' : (9 : ℚ) * f < 5 * n := by exact_mod_cast h
  linarith

/-- `theorem1_half_bound_of_forall`'s `cons`-case workhorse: a single tier
    satisfying the honest-majority guard has Byzantine fraction below 1/2. -/
theorem theorem1_half_bound_of_forall_cons (n f : ℕ) (hn : 0 < n) (h : 2 * f < n) :
    (f : ℚ) / n < (1 : ℚ) / 2 :=
  tier_byzantine_fraction_bound n f hn h

/-- List-level honest-majority guard: if every tier `(n, f)` in `tiers`
    satisfies `2 * f < n`, every tier's Byzantine fraction is below 1/2. -/
theorem theorem1_half_bound_of_forall (tiers : List (ℕ × ℕ))
    (h : ∀ t ∈ tiers, 0 < t.1 ∧ 2 * t.2 < t.1) :
    ∀ t ∈ tiers, (t.2 : ℚ) / t.1 < (1 : ℚ) / 2 := by
  intro t ht
  exact theorem1_half_bound_of_forall_cons t.1 t.2 (h t ht).1 (h t ht).2

/-- The 5/9 bound is weaker than (implied by) the 1/2 honest-majority bound,
    since 1/2 < 5/9: any tier that clears the classical honest-majority guard
    a fortiori clears the looser 5/9 profile guard. -/
theorem theorem1_five_ninths_of_half_bound (n f : ℕ) (hn : 0 < n) (h : 2 * f < n) :
    (f : ℚ) / n < (5 : ℚ) / 9 := by
  have h_half := tier_byzantine_fraction_bound n f hn h
  have : (1 : ℚ) / 2 < 5 / 9 := by norm_num
  linarith

/-- Concrete tier check at the published committee size (n = 10M, committee
    c = 50,000, Byzantine f = 24,999) — matches `theorem1_mohawk_validation`. -/
theorem theorem1_tier_majority_checked :
    (24_999 : ℚ) / 50_000 < (1 : ℚ) / 2 :=
  tier_byzantine_fraction_bound 50_000 24_999 (by norm_num) (by norm_num)

/-- The 5/9 profile guard instantiated at the published 10M-node global
    scale: a Byzantine count of 5,555,555 clears the guard and so sits
    strictly below the 5/9 (~55.5%) threshold. -/
theorem theorem1_global_bound_checked :
    (5_555_555 : ℚ) / 10_000_000 < (5 : ℚ) / 9 :=
  theorem1_five_ninths_guard 10_000_000 5_555_555 (by norm_num) (by norm_num)

/-- Corollary: at Sovereign-Mohawk's target scale of 10M nodes, a Byzantine
    count up to 5,555,554 satisfies the 5/9 profile guard `9f < 5n`. -/
theorem theorem1_ten_million_corollary :
    9 * 5_555_554 < 5 * 10_000_000 := by norm_num

/-- Headline restatement: any tier config clearing the 5/9 profile guard has
    Byzantine fraction strictly below 5/9. This replaces the previous
    unconditional `∃ f_global ≥ 555/1000` statement, which held regardless of
    any input and proved nothing about the system. -/
theorem theorem1_hierarchical_bft_tolerance (n f : ℕ) (hn : 0 < n) (h : 9 * f < 5 * n) :
    (f : ℚ) / n < (5 : ℚ) / 9 :=
  theorem1_five_ninths_guard n f hn h

/-- Concrete Mohawk validation: at the published committee size, the
    Byzantine count clears both the strict honest-majority guard (2f < c)
    and the resulting fraction bound (f/c < 1/2). -/
theorem theorem1_mohawk_validation :
    let _n := 10_000_000
    let c := 50_000
    let f := 24_999
    2 * f < c ∧ (f : ℚ) / c < (1 : ℚ) / 2 := by
  refine ⟨by norm_num, ?_⟩
  exact tier_byzantine_fraction_bound 50_000 24_999 (by norm_num) (by norm_num)

/-! ## Hierarchical composition: attempted, found FALSE, counterexample below

This section is real Phase 1 work on the file's own stated future direction —
"a proof that recursive hierarchical composition of per-tier honest-majority
filtering converges to 55.5% [or any fixed fraction] globally" (see the file
header). The natural deterministic version of that claim is **not true**, and
this is proven below with a concrete, machine-checked counterexample — not
left unresolved, and not forced through with a broken proof.

### The model

`HTree` is a hierarchical aggregation tree: a `leaf` is a single node
(Byzantine or honest); a `node` aggregates a list of children (one tier
observing the next tier down, or a tier observing raw nodes). `safe t` is the
natural formalization of "every tier's local honest-majority guard holds,
recursively, weighted by actual subtree size (not just child count, which
would let an adversary hide corruption behind a numerically-small but
leaf-heavy branch)": a leaf is safe iff honest; a node is safe iff the total
leaf-weight of its *safe* children exceeds half its total leaf-weight.

### The claim, and why it's false

The natural theorem to want is: `t.safe → 2 * t.byzantineLeaves < t.totalLeaves`
— i.e. "every tier's local majority guard holding implies the true, global
fraction of Byzantine leaf nodes is below half." `hierarchical_composition_counterexample`
below is a 2-child, 3-level-deep instance where `Root.safe` holds but
`Root.byzantineLeaves = 3` out of `Root.totalLeaves = 5` (60% Byzantine) —
a direct, machine-checked disproof.

Why, mathematically: a "safe" child is only guaranteed *better than half*
honest internally — it can still harbor close to half its own leaves as
Byzantine. Crediting a safe child with its *full* leaf-weight (the only
option available to a parent that can't see past a child's aggregated
output) lets an adversary concentrate near-50%-Byzantine corruption inside
nominally-"safe" branches while *also* running a separate, wholly-Byzantine
"unsafe" branch — and the local majority check only bounds the *unsafe*
branch's weight relative to the *safe* branch's weight, not relative to how
much of the safe branch's own credited weight was actually honest. Redoing
the induction algebraically for *any* fixed per-level threshold θ (not just
1/2) shows the same gap reappears at every level — this isn't a threshold
tuning problem, it's structural: gate-based (trust-or-don't, no partial
credit) hierarchical aggregation cannot deterministically bound worst-case
global corruption via local majority guards alone, regardless of depth.

### What a true version would need

This matches why real hierarchical BFT / committee-based systems (this
repo's own architecture docs describe randomly-sampled committees, not a
fixed adversarial partition) rely on *probabilistic* arguments: if committee
membership is drawn via random sampling (or VRF/random-beacon selection) from
a population with a bounded *global* Byzantine fraction, the adversary cannot
choose which tier to concentrate corruption in, and a concentration bound
(hypergeometric/binomial tail) shows any single committee exceeding its local
threshold is exponentially unlikely — a genuinely different, measure-theoretic
formalization task from the deterministic worst-case claim disproven here,
and out of scope for this pass. The concrete 5/9 profile check above
(`theorem1_five_ninths_guard`, `theorem1_global_bound_checked`) remains a
real, correct fact about a *given* tier's Byzantine count — this section
does not change that; it closes out whether a general deterministic
hierarchical composition theorem exists (it doesn't), rather than leaving
that question implicit and unexamined.
-/

/-- A hierarchical aggregation tree: `leaf` is one node, tagged Byzantine or
    honest; `node` aggregates a list of children. -/
inductive HTree where
  | leaf (byzantine : Bool)
  | node (children : List HTree)

mutual
/-- Total leaf count in the subtree. -/
def HTree.totalLeaves : HTree → Nat
  | .leaf _ => 1
  | .node cs => HTree.totalLeavesList cs

def HTree.totalLeavesList : List HTree → Nat
  | [] => 0
  | c :: cs => c.totalLeaves + HTree.totalLeavesList cs
end

mutual
/-- True (ground-truth) count of Byzantine leaves in the subtree. -/
def HTree.byzantineLeaves : HTree → Nat
  | .leaf b => if b then 1 else 0
  | .node cs => HTree.byzantineLeavesList cs

def HTree.byzantineLeavesList : List HTree → Nat
  | [] => 0
  | c :: cs => c.byzantineLeaves + HTree.byzantineLeavesList cs
end

mutual
/-- Leaf-weight this subtree would be credited with by a parent applying the
    weighted local-majority rule: a leaf is credited 1 iff honest; a node is
    credited the sum, over its children, of each child's *full* leaf count
    if that child is itself locally safe (weighted majority holds), else 0. -/
def HTree.safeLeafWeight : HTree → Nat
  | .leaf b => if b then 0 else 1
  | .node cs => HTree.safeLeafWeightList cs

def HTree.safeLeafWeightList : List HTree → Nat
  | [] => 0
  | c :: cs =>
      (if 2 * c.safeLeafWeight > c.totalLeaves then c.totalLeaves else 0)
      + HTree.safeLeafWeightList cs
end

/-- A subtree is "safe" iff its safe-credited leaf-weight is a strict
    majority of its total leaf-weight — the recursive, weighted local
    honest-majority guard. -/
def HTree.safe (t : HTree) : Prop := 2 * t.safeLeafWeight > t.totalLeaves

/-- Counterexample witnesses. `A`: 3 leaves, 1 Byzantine (locally safe:
    2/3 honest). `B`: 2 leaves, both Byzantine (locally unsafe). `Root`:
    parent of `A` and `B`. -/
def hierarchical_counterexample_A : HTree := .node [.leaf false, .leaf false, .leaf true]
def hierarchical_counterexample_B : HTree := .node [.leaf true, .leaf true]
def hierarchical_counterexample_Root : HTree :=
  .node [hierarchical_counterexample_A, hierarchical_counterexample_B]

theorem hierarchical_counterexample_A_safe : hierarchical_counterexample_A.safe := by
  unfold HTree.safe; decide

theorem hierarchical_counterexample_B_not_safe : ¬ hierarchical_counterexample_B.safe := by
  unfold HTree.safe; decide

/-- `Root`'s weighted local-majority guard holds (its safe child `A`'s
    leaf-weight of 3 exceeds unsafe child `B`'s leaf-weight of 2). -/
theorem hierarchical_counterexample_Root_safe : hierarchical_counterexample_Root.safe := by
  unfold HTree.safe; decide

/-- THE COUNTEREXAMPLE: despite `Root.safe` holding, `Root` is 60% Byzantine
    (3 of 5 leaves) — the natural deterministic hierarchical composition
    theorem (`t.safe → 2 * t.byzantineLeaves < t.totalLeaves`) is false. -/
theorem hierarchical_composition_counterexample :
    hierarchical_counterexample_Root.safe ∧
    ¬ (2 * hierarchical_counterexample_Root.byzantineLeaves
        < hierarchical_counterexample_Root.totalLeaves) := by
  refine ⟨hierarchical_counterexample_Root_safe, ?_⟩
  unfold hierarchical_counterexample_Root hierarchical_counterexample_A
    hierarchical_counterexample_B
  decide

end LeanFormalization
