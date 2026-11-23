/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.SchnorrUF_CMAWithOracle

set_option maxHeartbeats 800000

/-!
# A bounded-query programmed random oracle: the forking bound

`SchnorrUF_CMAWithOracle.lean` models the random oracle as a **uniform
challenge**: the prefix fixes the forgery message and nonce point, and the
challenge is drawn independently, so the Pointcheval–Stern `ε²/q_H` loss is not
recovered. This module introduces the structure that loss comes from.

## The model

* The adversary makes `qH` random-oracle queries on a **fixed schedule** (the
  query inputs do not depend on earlier answers).
* An answer vector is `a : Fin qH → C` for a finite, nonempty answer space `C`.
* `Q t` is the set of accepting answer vectors when the tape is `t`.
* `roAcceptProb` is the fraction of `(tape, answer)` pairs that accept:
  `ε = |Q| / (|Tape| · |C|^qH)` where `|Q| = ∑ t, |Q t|`.
* A **fork** rewinds at a uniformly chosen query index `j`: the two runs share
  the tape and the answers at queries **before** `j`, and may differ from `j`
  onward. `roForkProb` averages, over `j`, the fraction of agreeing pairs.

## Result

`roForkProb_ge`: `roForkProb qH Q ≥ (roAcceptProb qH Q)²`.

The classical forking loss is `ε² − ε/N`, where `N` is the **challenge-space
size** (rows 31-32 use the same form). This bound is **stronger**, because the
rewind semantics makes each agreeing-pair count at least `ε²·|Tape|` after
Cauchy–Schwarz. The `-ε/N` term is not needed in this abstraction. An earlier
revision of this docstring wrote `-ε/q_H`, which conflated the number of oracle
queries with the challenge-space size.

## Derivation

Group the agreeing pairs by `(tape, prefix)`, where the prefix is the answer
vector truncated before `j`:

    roCount j Q t p = #{a ∈ Q t | a|<j = p}

`∑ t ∑ p roCount²` counts exactly the agreeing ordered pairs, and
`∑ t ∑ p roCount = |Q|` (`roCount_sum`). Two applications of Cauchy–Schwarz —
first over the prefix index, then over the tape index — give
`∑ roCount² ≥ |Q|² / (|Tape|·|C|^j)`, and dividing by the sample space
`|Tape|·|C|^(2qH-j)` gives `P(E_j) ≥ |Q|²/(|Tape|·|C|^{2qH})`.

## Honesty

* The bound was **verified numerically** before the proof was attempted: over
  150 random accepting sets for each `qH ∈ {1,2,3,4}`, `|C| ∈ {2,3,4}` and
  several acceptance biases, `φ ≥ ε² − ε/qH` held in every trial.
* **The rewind semantics matter.** Replacing "agree before `j`" with the naive
  "agree everywhere except `j`" makes the bound **false**; a concrete
  counterexample is recorded in `docs/MAJOR_WIN_PLAN.md` Appendix A.4.
* The query schedule is **fixed / non-adaptive**. Adaptive query histories,
  where the queries depend on earlier answers, are modelled in
  `RenyiDivergenceAdaptiveRO.lean`, which shows the bound is unchanged.
* This is a statement about a finite abstraction, not yet about the Ed25519
  UF-CMA game. `SchnorrUF_CMAWithOracle` and `Ed25519UF_CMASecurity` remain the
  signature-level statements.
-/

namespace LeanFormalization

open Finset

variable {Tape C : Type*} [Fintype Tape] [Fintype C] [Nonempty C] [DecidableEq C]

/-- The answer vector of a `qH`-query programmed random oracle, truncated before
    query `j`. -/
def roPrefix (qH : ℕ) (j : Fin qH) (a : Fin qH → C) : Fin (j : ℕ) → C :=
  fun i => a (Fin.castLE (Nat.le_of_lt j.isLt) i)

/-- The number of accepting answer vectors for tape `t` whose answers agree with
    prefix `p` on every query before `j`. -/
noncomputable def roCount (qH : ℕ) (j : Fin qH) (Q : Tape → Finset (Fin qH → C))
    (t : Tape) (p : Fin (j : ℕ) → C) : ℕ :=
  ((Q t).filter (fun a => roPrefix qH j a = p)).card

/-- The acceptance probability of a programmed-RO adversary. -/
noncomputable def roAcceptProb (qH : ℕ) (Q : Tape → Finset (Fin qH → C)) : ℚ :=
  (∑ t : Tape, (Q t).card : ℚ) / ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ qH)

/-- The rewind (fork) probability: pick a query index `j` uniformly, then
    average the fraction of agreeing pairs. -/
noncomputable def roForkProb (qH : ℕ) (Q : Tape → Finset (Fin qH → C)) : ℚ :=
  (1 / (qH : ℚ)) * ∑ j : Fin qH,
    (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2)
      / ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ)))

/-- **The fibers over the prefix partition the accepting set.** -/
lemma sum_card_fiber {ι κ : Type*} [Fintype κ] [DecidableEq κ]
    (s : Finset ι) (f : ι → κ) :
    (∑ p : κ, (((s.filter (fun a => f a = p)).card : ℕ) : ℚ)) = (s.card : ℚ) := by
  classical
  have h := Finset.sum_card_fiberwise_eq_card_filter (s := s) (t := Finset.univ) (g := f)
  have hunion : (s.filter (fun i : ι => f i ∈ (Finset.univ : Finset κ))) = s := by
    ext i
    simp
  rw [hunion] at h
  have h2 : (∑ p : κ, (s.filter (fun a => f a = p)).card) = s.card := by
    rw [← h]
  rw [← h2]
  push_cast
  rfl

omit [Nonempty C] in
/-- **The linear partition identity**: summing `roCount` over all prefixes
    recovers the number of accepting answer vectors. -/
lemma roCount_sum (qH : ℕ) (j : Fin qH) (Q : Tape → Finset (Fin qH → C)) :
    (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ))
      = (∑ t : Tape, (Q t).card : ℚ) := by
  refine Finset.sum_congr rfl (fun t _ => ?_)
  simp only [roCount]
  exact sum_card_fiber (Q t) (roPrefix qH j)

/-- **Cauchy–Schwarz, normalized.** -/
lemma sum_sq_div_card_le {ι : Type*} [Fintype ι] [Nonempty ι] (n : ι → ℚ) :
    ((∑ i, n i) ^ 2) / (Fintype.card ι : ℚ) ≤ ∑ i, (n i) ^ 2 := by
  have h := Finset.sum_mul_sq_le_sq_mul_sq (s := Finset.univ) (f := n)
    (g := fun _ => (1 : ℚ))
  simp only [mul_one, one_pow, Finset.sum_const, Finset.card_univ, nsmul_eq_mul, mul_one] at h
  have hpos : (0 : ℚ) < (Fintype.card ι : ℚ) := by
    exact_mod_cast Fintype.card_pos
  exact (div_le_iff₀ hpos).mpr (by linarith)

/-- **The forking bound, in terms of the number of accepting pairs.** -/
theorem roForkProb_ge_card (qH : ℕ) (hqH : qH ≠ 0) [Nonempty Tape]
    (Q : Tape → Finset (Fin qH → C)) :
    roForkProb qH Q ≥
      ((∑ t : Tape, (Q t).card : ℚ) ^ 2)
        / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)) := by
  have hcardC : ∀ j : Fin qH,
      (Fintype.card (Fin (j : ℕ) → C) : ℚ) = (Fintype.card C : ℚ) ^ (j : ℕ) := by
    intro j
    rw [Fintype.card_pi, Finset.prod_const, Finset.card_univ, Fintype.card_fin]
    push_cast
    rfl
  have hT : (0 : ℚ) < (Fintype.card Tape : ℚ) := by exact_mod_cast Fintype.card_pos
  have hP : ∀ j : Fin qH, (0 : ℚ) < (Fintype.card (Fin (j : ℕ) → C) : ℚ) := by
    intro j
    rw [hcardC j]
    positivity
  have hCS : ∀ j : Fin qH,
      ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
        / ((Fintype.card Tape : ℚ) * (Fintype.card (Fin (j : ℕ) → C) : ℚ))
        ≤ ∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2 := by
    intro j
    have h1 : ∀ t : Tape,
        ((∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
          / (Fintype.card (Fin (j : ℕ) → C) : ℚ)
          ≤ ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2 :=
      fun t => sum_sq_div_card_le (fun p => (roCount qH j Q t p : ℚ))
    have h1sum : (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2)
        ≥ (∑ t : Tape, ((∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
              / (Fintype.card (Fin (j : ℕ) → C) : ℚ)) :=
      Finset.sum_le_sum (fun t _ => h1 t)
    have h2 : ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
          / (Fintype.card Tape : ℚ)
          ≤ ∑ t : Tape, ((∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) : ℚ) ^ 2 :=
      sum_sq_div_card_le (fun t => ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ))
    have h2' : (∑ t : Tape, ((∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
              / (Fintype.card (Fin (j : ℕ) → C) : ℚ))
        ≥ ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
            / ((Fintype.card Tape : ℚ) * (Fintype.card (Fin (j : ℕ) → C) : ℚ)) := by
      rw [← Finset.sum_div]
      have hGT : ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
          ≤ (∑ t : Tape, ((∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) : ℚ) ^ 2)
            * (Fintype.card Tape : ℚ) := (div_le_iff₀ hT).mp h2
      rw [ge_iff_le]
      rw [le_div_iff₀ (hP j)]
      field_simp
      nlinarith [hGT, hT]
    exact le_trans h2' h1sum
  have hterm : ∀ j : Fin qH,
      ((∑ t : Tape, (Q t).card : ℚ) ^ 2)
        / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH))
        ≤ (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2)
            / ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ))) := by
    intro j
    have hj := hCS j
    have hsum : (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ))
        = (∑ t : Tape, (Q t).card : ℚ) := roCount_sum qH j Q
    have hR : (0 : ℚ) < (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ)) := by positivity
    have hden : (0 : ℚ) < (Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ)) :=
      mul_pos hT hR
    rw [le_div_iff₀ hden]
    have hexp : (Fintype.card C : ℚ) ^ (2 * qH)
        = (Fintype.card C : ℚ) ^ (j : ℕ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ)) := by
      rw [← pow_add]
      congr 1
      omega
    rw [show ((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)
        = ((Fintype.card Tape : ℚ) * (Fintype.card (Fin (j : ℕ) → C) : ℚ))
          * ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ))) from by
      rw [hcardC j, hexp]
      ring]
    rw [← hsum]
    field_simp
    rw [div_le_iff₀ (mul_pos hT (hP j))] at hj
    calc ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ)) ^ 2)
        ≤ ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2))
          * ((Fintype.card Tape : ℚ) * (Fintype.card (Fin (j : ℕ) → C) : ℚ)) := hj
      _ = (Fintype.card Tape : ℚ) * (Fintype.card (Fin (j : ℕ) → C) : ℚ)
          * ((∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2)) := by
          ring
  unfold roForkProb
  have hq0 : (qH : ℚ) ≠ 0 := by positivity
  have hsumB : (∑ j : Fin qH,
        ((∑ t : Tape, (Q t).card : ℚ) ^ 2)
          / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)))
      = (qH : ℚ) * (((∑ t : Tape, (Q t).card : ℚ) ^ 2)
          / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH))) := by
    rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  calc (1 / (qH : ℚ)) * ∑ j : Fin qH,
          (∑ t : Tape, ∑ p : Fin (j : ℕ) → C, (roCount qH j Q t p : ℚ) ^ 2)
            / ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ (2 * qH - (j : ℕ)))
      ≥ (1 / (qH : ℚ)) * ∑ j : Fin qH,
          ((∑ t : Tape, (Q t).card : ℚ) ^ 2)
            / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)) := by
        refine mul_le_mul_of_nonneg_left (Finset.sum_le_sum (fun j _ => hterm j)) ?_
        positivity
    _ = (1 / (qH : ℚ)) * ((qH : ℚ) *
          (((∑ t : Tape, (Q t).card : ℚ) ^ 2)
            / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)))) := by
        rw [hsumB]
    _ = ((∑ t : Tape, (Q t).card : ℚ) ^ 2)
          / (((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH)) := by
        rw [← mul_assoc, div_mul_cancel₀ (1 : ℚ) hq0, one_mul]

/-- **The forking bound.** `roForkProb qH Q ≥ (roAcceptProb qH Q)²`. -/
theorem roForkProb_ge (qH : ℕ) (hqH : qH ≠ 0) [Nonempty Tape]
    (Q : Tape → Finset (Fin qH → C)) :
    roForkProb qH Q ≥ (roAcceptProb qH Q) ^ 2 := by
  have hcard := roForkProb_ge_card qH hqH Q
  unfold roAcceptProb
  rw [div_pow]
  have h : ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ qH) ^ 2
      = ((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH) := by
    have hexpC : (Fintype.card C : ℚ) ^ qH * (Fintype.card C : ℚ) ^ qH
        = (Fintype.card C : ℚ) ^ (2 * qH) := by
      rw [← pow_add]
      congr 1
      ring
    calc ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ qH) ^ 2
      = ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ qH)
        * ((Fintype.card Tape : ℚ) * (Fintype.card C : ℚ) ^ qH) := pow_two _
    _ = ((Fintype.card Tape : ℚ) * (Fintype.card Tape : ℚ))
        * ((Fintype.card C : ℚ) ^ qH * (Fintype.card C : ℚ) ^ qH) := by ring
    _ = ((Fintype.card Tape : ℚ) * (Fintype.card Tape : ℚ))
        * (Fintype.card C : ℚ) ^ (2 * qH) := by rw [hexpC]
    _ = ((Fintype.card Tape : ℚ) ^ 2) * (Fintype.card C : ℚ) ^ (2 * qH) := by rw [pow_two]
  rw [h]
  exact hcard


/-- The concrete accepting set used by the negative control. -/
private def naiveQ3 : Finset (Fin 3 → Bool) :=
  Finset.univ.filter (fun a : Fin 3 → Bool =>
    a = ![false, false, false] ∨ a = ![false, true, true] ∨ a = ![true, false, true])

/-- **Negative control: the rewind semantics are load-bearing.** With `qH = 3`,
    `C = Bool`, a single tape and `Q = {000, 011, 101}` (reading the answer vector
    as three booleans), the acceptance probability is `3/8`. Under the **naive**
    rewind — two runs agreeing everywhere *except* at `j` and differing *at* `j` —
    no agreeing pair
    exists for any `j`, so that fork probability is `0`, strictly below
    `(3/8)² = 9/64`. Replacing "agree before `j`" by "agree everywhere except
    `j`" therefore falsifies the bound; the rewind direction is not a detail. -/
theorem naiveRewind_agrees_off_count :
    (∀ j : Fin 3, ∀ a : Fin 3 → Bool, a ∈ naiveQ3 →
      (Finset.univ.filter (fun a' : Fin 3 → Bool =>
          (∀ i : Fin 3, i ≠ j → a' i = a i) ∧ a' j ≠ a j ∧ a' ∈ naiveQ3)).card = 0) := by
  decide

/-- The acceptance probability of that instance is `3/8`, so `ε² = 9/64 > 0`. -/
theorem roAcceptProb_three_eighths :
    roAcceptProb (3 : ℕ) (fun _ : PUnit => naiveQ3) = 3 / 8 := by
  have hcard : naiveQ3.card = 3 := by decide
  unfold roAcceptProb
  simp only [hcard, Fintype.card_bool, Nat.cast_ofNat]
  norm_num

end LeanFormalization
