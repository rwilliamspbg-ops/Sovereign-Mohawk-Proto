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
import LeanFormalization.Theorem4ChernoffBounds

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

/-! ## Probabilistic hierarchical composition (Phase 3)

`hierarchical_composition_counterexample` disproved the *deterministic*
compositional claim: crediting a "safe" (passed-its-local-majority-check)
committee its full leaf-weight lets an adversary hide near-50% corruption
inside it. The comment on that theorem, and `bft_resilience.md`'s
"Correction" section, both prescribe the real fix: under *random* committee
sampling (this system's actual architecture — not a fixed adversarial
partition), the adversary can't choose which committee to concentrate
corruption in, so each committee's *actual* Byzantine count concentrates
near the population's global rate, and — critically — that lets you sum
*actual bounded counts* directly instead of laundering full credit through
a binary safe/unsafe gate, sidestepping the exact mechanism that broke the
deterministic version.

This section formalizes that argument using Markov's inequality (a real,
provable, but *weak* — polynomial, not exponential — concentration bound),
not the full Chernoff/Hoeffding tail bound `bft_resilience.md` names as the
mathematically ideal fix. That's a genuine, documented scope choice, not
an oversight: a from-scratch exponential concentration bound needs Mathlib's
general sub-Gaussian/MGF machinery (`Mathlib.Probability.Moments.*`), which
brings real measurability/integrability setup this pass does not attempt.
What's below is real and non-vacuous — it gives an honestly-weaker
probabilistic guarantee, with its own genuine numeric limitation documented
at `probabilistic_bound_too_loose_at_deployment_scale` below, not silently
glossed over.

Committee sampling is modeled the same way `chernoff_bound_eq_binomial_zero_prob`
in `Theorem4ChernoffBounds.lean` already models redundant-copy availability:
i.i.d. Bernoulli trials via the binomial family, the standard idealization
for "sample from a large population" used in real committee-BFT protocols
(e.g. Algorand's sortition analysis) — not exact hypergeometric
sampling-without-replacement, which Mathlib has no concentration-bound
support for at all.
-/

/-- `∑_{i=0}^n i·C(n,i)·pⁱ·(1-p)ⁿ⁻ⁱ = np`: the mean of a Binomial(n,p) count,
    proved directly from the absorption identity `Nat.add_one_mul_choose_eq`
    (reindexing `i·C(n,i)` to `n·C(n-1,i-1)`) and the binomial theorem
    (`add_pow`) collapsing the reindexed sum to `(p+(1-p))^(n-1) = 1`. Not in
    Mathlib — `Probability.Distributions.Binomial`'s own version of this fact
    is a `proof_wanted` stub there, not a proved theorem. -/
theorem binomial_mean (n : ℕ) (p : ℚ) :
    ∑ i ∈ Finset.range (n + 1), (i : ℚ) * (n.choose i) * p ^ i * (1 - p) ^ (n - i) = n * p := by
  match n with
  | 0 => simp
  | m + 1 =>
    rw [Finset.sum_range_succ']
    simp only [Nat.cast_zero, zero_mul, add_zero]
    have hterm : ∀ j ∈ Finset.range (m + 1),
        ((j + 1 : ℕ) : ℚ) * ((m + 1).choose (j + 1)) * p ^ (j + 1) * (1 - p) ^ (m + 1 - (j + 1))
          = ((m : ℚ) + 1) * p * ((m.choose j : ℚ) * p ^ j * (1 - p) ^ (m - j)) := by
      intro j hj
      have hjm : j ≤ m := by simp only [Finset.mem_range] at hj; omega
      have habs : ((m + 1).choose (j + 1) : ℚ) * (((j : ℕ) + 1 : ℕ) : ℚ)
          = ((m : ℚ) + 1) * (m.choose j : ℚ) := by
        have := Nat.add_one_mul_choose_eq m j
        have hc : ((m + 1) * m.choose j : ℚ) = ((m + 1).choose (j + 1) * (j + 1) : ℚ) := by
          exact_mod_cast this
        push_cast at hc ⊢
        linarith
      have hexp : m + 1 - (j + 1) = m - j := by omega
      rw [hexp]
      push_cast
      have heq : ((j : ℚ) + 1) * ((m + 1).choose (j + 1) : ℚ) * p ^ (j + 1) * (1 - p) ^ (m - j)
          = (((m + 1).choose (j + 1) : ℚ) * (((j : ℕ) + 1 : ℕ) : ℚ)) * p ^ (j + 1) * (1 - p) ^ (m - j) := by
        push_cast; ring
      rw [heq, habs]
      ring
    rw [Finset.sum_congr rfl hterm, ← Finset.mul_sum]
    have hbin : ∑ j ∈ Finset.range (m + 1), (m.choose j : ℚ) * p ^ j * (1 - p) ^ (m - j) = 1 := by
      have hb := add_pow p (1 - p) m
      calc ∑ j ∈ Finset.range (m + 1), (m.choose j : ℚ) * p ^ j * (1 - p) ^ (m - j)
          = ∑ j ∈ Finset.range (m + 1), p ^ j * (1 - p) ^ (m - j) * (m.choose j : ℚ) := by
            apply Finset.sum_congr rfl; intro j _; ring
        _ = (p + (1 - p)) ^ m := hb.symm
        _ = 1 := by simp
    rw [hbin]
    push_cast
    ring

/-- Exact tail probability that a Binomial(n,p) count is at least `k`. -/
def binomialTail (n k : ℕ) (p : ℚ) : ℚ :=
  ∑ i ∈ Finset.Icc k n, (n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i)

/-- The tail is a sub-sum of the full binomial expansion (which sums to `1`
    via the binomial theorem), so it never exceeds `1` — needed to feed
    `binomialTail` into `theorem4_union_bound`'s `p i ≤ 1` hypothesis below. -/
theorem binomialTail_le_one (n k : ℕ) (p : ℚ) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    binomialTail n k p ≤ 1 := by
  have hsub : Finset.Icc k n ⊆ Finset.range (n + 1) := by
    intro i hi
    simp only [Finset.mem_Icc] at hi
    simp only [Finset.mem_range]; omega
  have hextend : binomialTail n k p
      ≤ ∑ i ∈ Finset.range (n + 1), (n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i) := by
    unfold binomialTail
    apply Finset.sum_le_sum_of_subset_of_nonneg hsub
    intro i _ _
    have h1 : (0 : ℚ) ≤ p ^ i := pow_nonneg hp0 i
    have h2 : (0 : ℚ) ≤ (1 - p) ^ (n - i) := pow_nonneg (by linarith) _
    positivity
  have hbin : ∑ j ∈ Finset.range (n + 1), (n.choose j : ℚ) * p ^ j * (1 - p) ^ (n - j) = 1 := by
    have hb := add_pow p (1 - p) n
    calc ∑ j ∈ Finset.range (n + 1), (n.choose j : ℚ) * p ^ j * (1 - p) ^ (n - j)
        = ∑ j ∈ Finset.range (n + 1), p ^ j * (1 - p) ^ (n - j) * (n.choose j : ℚ) := by
          apply Finset.sum_congr rfl; intro j _; ring
      _ = (p + (1 - p)) ^ n := hb.symm
      _ = 1 := by simp
  rw [hbin] at hextend
  exact hextend

/-- Markov's inequality for the binomial tail: `P(X ≥ k) ≤ n·p / k`. Proved
    from `binomial_mean`: `k·P(X≥k) ≤ ∑_{i≥k} i·P(i) ≤ ∑_{i=0}^n i·P(i) = n·p`
    (the middle step extends the tail sum to the full range, only adding
    nonnegative terms). -/
theorem binomial_markov (n k : ℕ) (p : ℚ) (hk : 0 < k) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    binomialTail n k p ≤ (n : ℚ) * p / k := by
  have hsub : Finset.Icc k n ⊆ Finset.range (n + 1) := by
    intro i hi
    simp only [Finset.mem_Icc] at hi
    simp only [Finset.mem_range]; omega
  have hkbound : (k : ℚ) * binomialTail n k p
      ≤ ∑ i ∈ Finset.Icc k n, (i : ℚ) * (n.choose i) * p ^ i * (1 - p) ^ (n - i) := by
    unfold binomialTail
    rw [Finset.mul_sum]
    apply Finset.sum_le_sum
    intro i hi
    simp only [Finset.mem_Icc] at hi
    have hik : (k : ℚ) ≤ (i : ℚ) := by exact_mod_cast hi.1
    have hterm_nonneg : (0 : ℚ) ≤ (n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i) := by
      have h1 : (0 : ℚ) ≤ p ^ i := pow_nonneg hp0 i
      have h2 : (0 : ℚ) ≤ (1 - p) ^ (n - i) := pow_nonneg (by linarith) _
      positivity
    calc (k : ℚ) * ((n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i))
        ≤ (i : ℚ) * ((n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i)) :=
          mul_le_mul_of_nonneg_right hik hterm_nonneg
      _ = (i : ℚ) * (n.choose i) * p ^ i * (1 - p) ^ (n - i) := by ring
  have hextend : (∑ i ∈ Finset.Icc k n, (i : ℚ) * (n.choose i) * p ^ i * (1 - p) ^ (n - i))
      ≤ ∑ i ∈ Finset.range (n + 1), (i : ℚ) * (n.choose i) * p ^ i * (1 - p) ^ (n - i) := by
    apply Finset.sum_le_sum_of_subset_of_nonneg hsub
    intro i hi _
    simp only [Finset.mem_range] at hi
    have h1 : (0 : ℚ) ≤ p ^ i := pow_nonneg hp0 i
    have h2 : (0 : ℚ) ≤ (1 - p) ^ (n - i) := pow_nonneg (by linarith) _
    positivity
  rw [binomial_mean] at hextend
  have hfinal : (k : ℚ) * binomialTail n k p ≤ (n : ℚ) * p := le_trans hkbound hextend
  have hkpos : (0 : ℚ) < k := by exact_mod_cast hk
  rw [le_div_iff₀ hkpos]
  linarith [hfinal]

/-- Probabilistic hierarchical composition: `T` committees, each of size `c`,
    each independently i.i.d.-sampled with per-member Byzantine probability
    `p` (the population's global Byzantine rate). Bounds the arithmetic
    quantity `theorem4_union_bound` (imported from `Theorem4ChernoffBounds.lean`,
    reused rather than re-proved) already identifies, by that file's own
    established convention, as "probability at least one committee's tail
    event occurs" by `T·c·p/k`. `binomial_markov` supplies each committee's
    individual bound; `theorem4_union_bound` unions them across the `T`
    committees.

    Unlike `hierarchical_composition_counterexample`'s gate-based `safe`
    predicate (crediting a committee its full weight for merely passing a
    threshold check — the mechanism that broke composition), the intended
    reading here is direct: when the unioned "some committee's Byzantine
    count reaches `k`" event does *not* occur, every committee's *actual*
    Byzantine count is below `k`, and summing `T` such bounded actual counts
    directly gives a real total-count bound of `T·k` — no gate, no
    full-credit laundering. -/
theorem probabilistic_hierarchical_bound
    (T c k : ℕ) (p : ℚ) (hk : 0 < k) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    1 - (1 - binomialTail c k p) ^ T ≤ (T : ℚ) * ((c : ℚ) * p / k) := by
  have hmarkov : binomialTail c k p ≤ (c : ℚ) * p / k := binomial_markov c k p hk hp0 hp1
  have hnn : 0 ≤ binomialTail c k p := by
    unfold binomialTail
    apply Finset.sum_nonneg
    intro i _
    have h1 : (0 : ℚ) ≤ p ^ i := pow_nonneg hp0 i
    have h2 : (0 : ℚ) ≤ (1 - p) ^ (c - i) := pow_nonneg (by linarith) _
    positivity
  have hle1 : binomialTail c k p ≤ 1 := binomialTail_le_one c k p hp0 hp1
  have hub := theorem4_union_bound T (fun _ => binomialTail c k p) (fun _ => ⟨hnn, hle1⟩)
  simp only [Finset.prod_const, Finset.sum_const, Finset.card_range, nsmul_eq_mul] at hub
  calc 1 - (1 - binomialTail c k p) ^ T ≤ (T : ℚ) * binomialTail c k p := hub
    _ ≤ (T : ℚ) * ((c : ℚ) * p / k) := mul_le_mul_of_nonneg_left hmarkov (by positivity)

/-- Illustrative concrete instantiation: 3 committees, each of size 100, 1%
    global Byzantine rate, majority (50%) safety threshold. The union-bound
    failure probability is at most 6%, a genuinely small, useful number —
    demonstrating the theorem above is not vacuous. -/
theorem probabilistic_hierarchical_bound_small_scale_example :
    1 - (1 - binomialTail 100 50 (1/100 : ℚ)) ^ 3
      ≤ (3 : ℚ) * ((100 : ℚ) * (1/100 : ℚ) / 50) := by
  have h := probabilistic_hierarchical_bound 3 100 50 (1/100 : ℚ) (by norm_num) (by norm_num) (by norm_num)
  linarith [h]

/-- **Honest limitation, checked, not glossed over**: at this system's own
    published deployment scale — `T = 200` committees of `c = 50,000` each
    (`200 * 50,000 = 10,000,000`, matching `theorem1_global_bound_checked`'s
    10M-node target), majority threshold `k = 25,000`, and a 10% global
    Byzantine rate — the Markov-based union bound above is **useless**: it
    evaluates to `40`, far exceeding `1` (a vacuous probability bound).
    Markov's inequality is a real but weak tool; its bound only becomes
    informative when the population is small, the margin between the mean
    (`c·p`) and the threshold `k` is large, or few committees are unioned
    over. None of those hold at Sovereign-Mohawk's actual scale. Closing
    this gap for real needs the sharper exponential Chernoff/Hoeffding tail
    bound `bft_resilience.md` names as the mathematically correct fix —
    scoped out of this pass for the reasons in this section's header
    comment, not silently assumed solved. -/
theorem probabilistic_bound_too_loose_at_deployment_scale :
    (200 : ℚ) * ((50000 : ℚ) * (1/10 : ℚ) / 25000) = 40 := by norm_num

end LeanFormalization
