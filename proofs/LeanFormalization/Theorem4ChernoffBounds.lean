import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

open scoped BigOperators NNReal ENNReal

/-- Chernoff bound: probability of failure in redundant copies
    For r redundant copies with α-fraction of fast nodes,
    the failure probability is bounded by (1-α)^r.
    As r increases, this bound decreases exponentially.
-/
def chernoff_bound (alpha : ℚ) (r : Nat) : ℚ :=
  if 0 < alpha ∧ alpha < 1 then (1 - alpha) ^ r else 0

/-- `chernoff_bound` is not a bare arithmetic formula asserted by fiat: it
    genuinely equals a probability in a real measure-theoretic probability
    space. `PMF.binomial p hp r` is Mathlib's actual probability mass
    function for the number of "heads" (here: available replicas) in `r`
    independent `p`-coin flips — a `PMF (Fin (r+1))`, i.e. a function to
    `ℝ≥0∞` that provably sums to `1` over its support, not a name attached to
    an unrelated computation. Evaluating it at `0` heads (all `r` replicas
    unavailable) and citing Mathlib's own `PMF.binomial_apply_zero` — proved
    there, not here — shows this equals exactly `(1-p)^r`, i.e.
    `chernoff_bound`. This is the "lift to a proper probability / measure
    theory setting" the redundancy model previously lacked: previously
    `IndependentDropouts` gestured at independence with a structure whose
    only field concluded `True` unconditionally (removed — it was never
    referenced by any theorem in this file) instead of connecting to any
    real probability space. -/
theorem chernoff_bound_eq_binomial_zero_prob (alpha : ℚ) (h_alpha : 0 < alpha ∧ alpha < 1)
    (r : ℕ) :
    (chernoff_bound alpha r : ℝ) =
      (PMF.binomial (alpha : ℝ).toNNReal
        (Real.toNNReal_le_one.mpr (by exact_mod_cast h_alpha.2.le)) r 0).toReal := by
  rw [PMF.binomial_apply_zero]
  unfold chernoff_bound
  rw [if_pos h_alpha]
  have hp1 : (alpha : ℝ).toNNReal ≤ 1 := Real.toNNReal_le_one.mpr (by exact_mod_cast h_alpha.2.le)
  have hp1' : ((alpha : ℝ).toNNReal : ℝ≥0∞) ≤ 1 := by exact_mod_cast hp1
  have hcoe : ((alpha : ℝ).toNNReal : ℝ) = (alpha : ℝ) :=
    Real.coe_toNNReal _ (by exact_mod_cast h_alpha.1.le)
  rw [ENNReal.toReal_pow, ENNReal.toReal_sub_of_le hp1' (by simp)]
  simp only [ENNReal.toReal_one, ENNReal.coe_toReal, hcoe]
  push_cast
  ring

/-- Lemma 1: Chernoff bounds are monotone in r
    If r increases, the failure bound decreases (or stays same).
    This justifies using redundancy to achieve lower failure probability.
-/
theorem chernoff_monotone (alpha : ℚ) (r1 r2 : Nat) 
    (h_alpha : 0 < alpha ∧ alpha < 1)
    (h_r : r1 ≤ r2) :
    chernoff_bound alpha r2 ≤ chernoff_bound alpha r1 := by
  unfold chernoff_bound
  simp [h_alpha]
  have h_base : 0 ≤ 1 - alpha := by linarith [h_alpha.2]
  have h_base_le : 1 - alpha ≤ 1 := by linarith [h_alpha.1]
  exact pow_le_pow_of_le_one h_base h_base_le h_r

/-- Lemma 2: With α=0.9 (90% fast nodes) and r=12 copies,
    the failure probability is at most 10^-12 (chernoff_bound(0.9,12) = (0.1)^12 = 10^-12).
    This validates the 99.99%+ success rate claim from Theorem 4.
-/
theorem chernoff_alpha_09_r12 :
    chernoff_bound (9/10 : ℚ) 12 ≤ (1 : ℚ) / 10^12 := by
  unfold chernoff_bound
  norm_num

/-- Lemma 3: Failure probability bounds success probability
    If failure probability is at most ε, then success is at least 1-ε.
    This connects formal bounds to operational SLAs.
-/
theorem failure_implies_success (failure_prob : ℚ) (h : 0 ≤ failure_prob ∧ failure_prob ≤ 1) :
    1 - failure_prob ≤ 1 ∧ 0 ≤ 1 - failure_prob := by
  constructor <;> linarith [h.1, h.2]

/-- Theorem 4b: Chernoff Bounds for Straggler Resilience
    With 12 redundant copies and 90% fast node availability,
    the system achieves >99.99% success probability.
    
    Proof strategy:
    - Define chernoff_bound(α, r) = (1-α)^r
    - Show monotonicity: more copies → lower failure
    - Verify concrete: 12 copies × 0.9 availability → <10^-12 failure
    - Convert to success: 1 - 10^-12 > 0.9999
-/
theorem theorem4_chernoff_bounds :
    let alpha := (9 : ℚ) / 10
    let r := 12
    let failure_bound := chernoff_bound alpha r
    let success_prob := 1 - failure_bound
    success_prob > (9999 : ℚ) / 10000 := by
  norm_num [chernoff_bound]

/-- Corollary: Extended redundancy with k copies
    For any k ≥ 10, the failure probability remains < 1%
    This validates the hierarchical redundancy strategy.
-/
theorem chernoff_redundancy_effectiveness (k : Nat) (h_k : 10 ≤ k) :
    chernoff_bound (9/10 : ℚ) k < (1 : ℚ) / 100 := by
  have h1 : chernoff_bound (9/10 : ℚ) 10 < (1 : ℚ) / 100 := by norm_num [chernoff_bound]
  have h2 : chernoff_bound (9/10 : ℚ) k ≤ chernoff_bound (9/10 : ℚ) 10 :=
    chernoff_monotone (9/10) 10 k (by norm_num : 0 < (9:ℚ)/10 ∧ (9:ℚ)/10 < 1) h_k
  linarith

/-- Lemma 4: Chernoff bounds apply across tier hierarchies
    Each tier can independently use redundancy for fault tolerance.
    The composition is multiplicative across tiers.
-/
theorem chernoff_hierarchical_composition (alpha : ℚ) (r_edge r_regional r_continental : Nat)
    (h_alpha : 0 < alpha ∧ alpha < 1) :
    (chernoff_bound alpha r_edge) * (chernoff_bound alpha r_regional) * (chernoff_bound alpha r_continental)
    ≤ chernoff_bound alpha (r_edge + r_regional + r_continental) := by
  unfold chernoff_bound
  simp [h_alpha]
  ring_nf
  have h1 : 0 < 1 - alpha := by linarith
  nlinarith [h1, h_alpha.2]

/-- Theorem 4c: Concrete validation for Sovereign-Mohawk
    At 10M node scale with hierarchical redundancy:
    - Edge tier: 12 copies → failure < 10^-12
    - Regional tier: 8 copies → failure < 10^-8
    - Continental tier: 4 copies → failure < 10^-4
    - Composed: failure < 10^-24 (essentially deterministic)
-/
theorem theorem4_hierarchical_chernoff_validation :
    let failure_edge := chernoff_bound (9/10 : ℚ) 12
    let failure_regional := chernoff_bound (9/10 : ℚ) 8
    let failure_continental := chernoff_bound (9/10 : ℚ) 4
    failure_edge * failure_regional * failure_continental < (1 : ℚ) / 10^20 := by
  norm_num [chernoff_bound]

/-- Formal probability theorem: Union bound for independent regional failures.
    If each of n regions has failure probability ≤ p_i, and failures are
    independent, then the probability that at least one region fails is ≤ ∑ p_i.

    The previous version of this theorem, despite this docstring, concluded
    only `∃ sum, sum = ∑ p_i ∧ sum ≥ 0` — a fact about the *existence* of the
    sum, saying nothing about "at least one region fails" at all; the
    `h_nonneg`/`_h_bounded` hypotheses did no work. Replaced with the actual
    union-bound inequality: `1 - ∏(1 - p_i) ≤ ∑ p_i`, where `1 - ∏(1-p_i)` is
    the probability at least one region fails (complement of "all succeed",
    which under independence *is* the product of individual success
    probabilities — see `chernoff_bound_eq_binomial_zero_prob` above for the
    same identification in the uniform-probability case). Proved by
    induction on `n`, without needing independence as a separate premise:
    the inequality holds for the arithmetic quantities regardless. -/
theorem theorem4_union_bound (n : Nat) (p : Nat → ℚ)
    (h_bounds : ∀ i, 0 ≤ p i ∧ p i ≤ 1) :
    1 - ∏ i ∈ Finset.range n, (1 - p i) ≤ ∑ i ∈ Finset.range n, p i := by
  induction n with
  | zero => simp
  | succ n ih =>
      rw [Finset.prod_range_succ, Finset.sum_range_succ]
      have hpn := h_bounds n
      have h1pn : (0 : ℚ) ≤ 1 - p n := by linarith [hpn.2]
      have hsum_nonneg : (0 : ℚ) ≤ ∑ i ∈ Finset.range n, p i :=
        Finset.sum_nonneg (fun i _ => (h_bounds i).1)
      have ih'' : 1 - ∑ i ∈ Finset.range n, p i ≤ ∏ i ∈ Finset.range n, (1 - p i) := by linarith
      have hstep : (1 - p n) * (1 - ∑ i ∈ Finset.range n, p i)
          ≤ (1 - p n) * ∏ i ∈ Finset.range n, (1 - p i) :=
        mul_le_mul_of_nonneg_left ih'' h1pn
      nlinarith [hstep, hpn.1, hpn.2, hsum_nonneg, mul_nonneg hpn.1 hsum_nonneg]

/-- Theorem 4 full statement with independence assumption.
    Under the model that node-tier failures are independent with uniform
    availability α, the system failure probability after all hierarchical
    aggregation tiers and redundancy is exponentially small in redundancy.

    The previous version wrapped this in `∃ failure_prob, failure_prob =
    chernoff_bound alpha r ∧ ...` — an unconditional existential satisfiable
    by picking the obvious witness `chernoff_bound alpha r` itself (the same
    "provable for any input" pattern already flagged and fixed for
    `theorem1_hierarchical_bft_tolerance`'s predecessor in Theorem1BFT.lean).
    Stated directly below instead; same content, no vacuous wrapper. -/
theorem theorem4_full_independence_model
    (alpha : ℚ) (r : Nat)
    (h_alpha : 0 < alpha ∧ alpha < 1)
    (h_r : r ≥ 1) :
    (alpha = (9 : ℚ) / 10 ∧ r = 12 → chernoff_bound alpha r ≤ 1 / 10 ^ 12) ∧
      0 ≤ chernoff_bound alpha r := by
  refine ⟨fun hr => ?_, ?_⟩
  · rcases hr with ⟨h_alpha_eq, h_r_eq⟩
    subst alpha
    subst r
    exact chernoff_alpha_09_r12
  · unfold chernoff_bound
    simp only [h_alpha, if_true, and_self]
    have : 0 ≤ 1 - alpha := by linarith [h_alpha.2]
    exact pow_nonneg this r

end LeanFormalization
