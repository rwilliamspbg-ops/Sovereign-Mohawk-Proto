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

end LeanFormalization
