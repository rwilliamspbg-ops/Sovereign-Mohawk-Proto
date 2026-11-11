import Mathlib
import LeanFormalization.Theorem1BFT

set_option exponentiation.threshold 200000

/-!
# Protocol-Level Safety for Hierarchical Multi-Krum

The traceability matrix row 1 records a **disproof**: deterministic hierarchical
composition of per-tier honest-majority guards does not bound the global
Byzantine fraction — `hierarchical_composition_counterexample` is a two-tier tree
in which every tier passes its local guard while 60% of the leaves are
Byzantine.

This module supplies the two things that disproof leaves missing: the
*corrected* deterministic accounting that does compose, and a *probabilistic*
protocol-level statement under an explicit network/adversary model.

## Part 1 — the corrected deterministic predicate

`HTree.safe` credits a child that passes its local guard its **full** leaf
weight, regardless of how close to 50% Byzantine it is internally. That is the
mechanism that breaks composition. The honest predicate is the one about the
*actual counts*:

    fractionSafe t  :=  2 * byzantineLeaves t < totalLeaves t

`fractionSafe` composes over children (sum of strict inequalities), which is
exactly what `safe` fails to do. The contrast with the counterexample tree is
recorded explicitly below.

## Part 2 — the probabilistic protocol statement

Under the stated network model — each node is independently Byzantine with
probability `p` (i.i.d. Bernoulli), which is the model
`chernoff_hierarchical_bound` already assumes — the number of Byzantine nodes
in a committee of size `c` is `Binomial(c, p)`, and `binomialTail c k p` is
exactly `P(X ≥ k)`.

Go's `MultiKrumSelect` refuses to run unless `n > 2f + 2`
(`internal/multikrum.go`). That precondition fails iff the realized Byzantine
count reaches `guardThreshold c = (c-1)/2`. So
`multikrum_guard_failure_prob` below is the probability, under the stated
network model, that **any** of `T` committees violates the runtime's own
precondition — a protocol-level statement, not a numeric guard.

## What is not claimed

* The selection-safety question — whether Multi-Krum's *selection* (not just
  its precondition) is safe — is **not** settled here. That needs a Krum score
  analysis under a clustering/separation model, which is not in this module.
* `fractionSafe` composing is a statement about counts, not a proof that the
  runtime computes those counts: the runtime does not know which nodes are
  Byzantine. It says what a correct accounting would need, and shows that the
  credited-weight rule is not it.
-/

namespace LeanFormalization

open scoped BigOperators

/-! ## Part 1: the corrected deterministic predicate -/

/-- The honest safety predicate, stated about the actual leaf counts rather
than the credited leaf weight `HTree.safe` uses. -/
def HTree.fractionSafe (t : HTree) : Prop := 2 * t.byzantineLeaves < t.totalLeaves

/-- `fractionSafe` is false for a Byzantine leaf and true for an honest leaf. -/
theorem HTree.fractionSafe_leaf_true : fractionSafe (.leaf false) := by
  unfold fractionSafe
  decide

theorem HTree.fractionSafe_leaf_false : ¬ fractionSafe (.leaf true) := by
  unfold fractionSafe
  decide

/-- **The corrected composition theorem.** If every child of a node has an
honest majority by actual count, then so does the node.

This is precisely what `HTree.safe` fails to give: `safe` credits a passing
child its full leaf weight, so a child at 49% Byzantine contributes as much
weight as a child at 0%, and the parent can be 60% Byzantine while every child
passes. `fractionSafe` is a statement about counts, and strict inequalities
sum. The nonempty hypothesis is needed only because the empty node has no
leaves and so is trivially not safe. -/
theorem HTree.fractionSafe_node_of_forall (cs : List HTree) (hcs : cs ≠ [])
    (h : ∀ c ∈ cs, fractionSafe c) : fractionSafe (.node cs) := by
  unfold fractionSafe
  induction cs with
  | nil => exact absurd rfl hcs
  | cons c rest ih =>
      have h' : fractionSafe c ∧ ∀ c ∈ rest, fractionSafe c := by simpa using h
      obtain ⟨hc, hrest⟩ := h'
      unfold fractionSafe at hc
      have hrest' : ∀ c ∈ rest, fractionSafe c := hrest
      have hsum : 2 * (c.byzantineLeaves + (HTree.node rest).byzantineLeaves)
          < c.totalLeaves + (HTree.node rest).totalLeaves := by
        by_cases hrestnil : rest = []
        · subst hrestnil
          simpa [HTree.byzantineLeavesList, HTree.totalLeavesList] using hc
        · have ih' := ih hrestnil hrest'
          unfold fractionSafe at ih'
          omega
      simpa [HTree.byzantineLeaves, HTree.totalLeaves,
        HTree.byzantineLeavesList, HTree.totalLeavesList] using hsum

/-- The counterexample tree, restated for the corrected predicate: `safe` holds
at the root, but the corrected `fractionSafe` does not — and the corrected
predicate also correctly flags the unsafe child `B` that `safe` credits with
zero weight while still letting the root pass. -/
theorem hierarchical_counterexample_safeButFractionUnsafe :
    hierarchical_counterexample_Root.safe ∧
    ¬ HTree.fractionSafe hierarchical_counterexample_Root ∧
    ¬ HTree.fractionSafe hierarchical_counterexample_B := by
  refine ⟨hierarchical_counterexample_Root_safe, ?_, ?_⟩
  · unfold HTree.fractionSafe
    decide
  · unfold HTree.fractionSafe
    decide

/-! ## Part 2: the probabilistic protocol statement -/

/-- The Multi-Krum guard threshold: Go's `MultiKrumSelect`
(`internal/multikrum.go`) refuses to run when `n ≤ 2f + 2`. For a committee of
size `c`, the precondition therefore fails iff the realized Byzantine count is
at least `guardThreshold c = (c-1)/2`. -/
def guardThreshold (c : ℕ) : ℕ := (c - 1) / 2

/-- `guardThreshold` is exactly the failure threshold of the runtime's
precondition: `c ≤ 2f + 2` iff `guardThreshold c ≤ f`. -/
theorem guardThreshold_correct (c f : ℕ) :
    c ≤ 2 * f + 2 ↔ guardThreshold c ≤ f := by
  unfold guardThreshold
  have h2 : (0 : ℕ) < 2 := by norm_num
  have hdiv : (c - 1) / 2 ≤ f ↔ c - 1 < 2 * (f + 1) := by
    have hlt : (c - 1) / 2 < f + 1 ↔ c - 1 < 2 * (f + 1) := by
      simpa [mul_comm] using
        (Nat.div_lt_iff_lt_mul (k := 2) (x := c - 1) (y := f + 1) h2)
    rw [← hlt]
    omega
  rw [hdiv]
  omega

/-- **Probabilistic protocol safety.** Under the stated i.i.d. Bernoulli
network model with Byzantine rate `p`, the probability that any of `T`
committees of size `c` violates the runtime's `n > 2f + 2` precondition is at
most `T * chernoffBoundZ c (guardThreshold c) p z`.

This is a direct specialization of `chernoff_hierarchical_bound` to the
threshold the runtime actually checks; the content is the identification
`guardThreshold c` = the precondition's failure point, proved by
`guardThreshold_correct`. -/
theorem multikrum_guard_failure_prob (T c : ℕ) (p z : ℚ)
    (hz : 1 ≤ z) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    1 - (1 - binomialTail c (guardThreshold c) p) ^ T
      ≤ (T : ℚ) * chernoffBoundZ c (guardThreshold c) p z :=
  chernoff_hierarchical_bound T c (guardThreshold c) p z hz hp0 hp1

/-- Concrete deployment-scale instance: 200 committees of 50,000 nodes at a 10%
Byzantine rate. At that committee size the runtime's precondition
`n > 2f + 2` fails once the realized Byzantine count reaches
`guardThreshold 50000 = 24999`, so this is the probability that **any**
committee refuses to run Multi-Krum. The bound is `400/10^1000` — twice the
`200/10^1000` of `chernoff_hierarchical_bound_deployment_scale`, because the
guard threshold `24999` is one below the majority-breaking `25000` that
instance uses. -/
theorem multikrum_guard_failure_deployment_scale :
    1 - (1 - binomialTail 50000 (guardThreshold 50000) (1/10 : ℚ)) ^ 200
      ≤ (400 : ℚ) / 10 ^ 1000 := by
  have hgt : guardThreshold 50000 = 24999 := by
    unfold guardThreshold
    norm_num
  rw [hgt]
  have hchernoff : binomialTail 50000 24999 (1/10 : ℚ)
      ≤ chernoffBoundZ 50000 24999 (1/10 : ℚ) 2 :=
    binomialTail_le_chernoffBoundZ 50000 24999 (1/10 : ℚ) 2
      (by norm_num) (by norm_num) (by norm_num)
  have htiny : chernoffBoundZ 50000 24999 (1/10 : ℚ) 2 ≤ 2 / 10 ^ 1000 := by
    have h := chernoffBoundZ_deployment_scale_tiny
    have hratio : chernoffBoundZ 50000 24999 (1/10 : ℚ) 2
        = 2 * chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 := by
      unfold chernoffBoundZ
      set_option exponentiation.threshold 200000 in
      rw [div_eq_mul_inv, div_eq_mul_inv]
      have h2k : (2:ℚ) ^ 25000 = 2 * 2 ^ 24999 := by
        rw [show (25000:ℕ) = 24999 + 1 from by norm_num, pow_succ']
      rw [h2k]
      ring_nf
    rw [hratio]
    have h2 : 2 * chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 ≤ 2 * (1 / 10 ^ 1000) :=
      mul_le_mul_of_nonneg_left h (by norm_num)
    calc 2 * chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 ≤ 2 * (1 / 10 ^ 1000) := h2
      _ = 2 / 10 ^ 1000 := by ring
  have hub := chernoff_hierarchical_bound 200 50000 24999 (1/10 : ℚ) 2
    (by norm_num) (by norm_num) (by norm_num)
  calc 1 - (1 - binomialTail 50000 24999 (1/10 : ℚ)) ^ 200
      ≤ (200 : ℚ) * chernoffBoundZ 50000 24999 (1/10 : ℚ) 2 := hub
    _ ≤ (200 : ℚ) * (2 / 10 ^ 1000) := by nlinarith [htiny]
    _ = (400 : ℚ) / 10 ^ 1000 := by ring

end LeanFormalization
