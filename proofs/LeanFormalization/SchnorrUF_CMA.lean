/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.SchnorrForking

/-!
# The random-oracle forking reduction for Schnorr / Ed25519

This file upgrades `SchnorrForking.lean` from "extractor, given a fork" to a
**quantitative reduction**: a forger's *success probability* is converted into a
probability that a *discrete-log solver* succeeds.

`SchnorrForking.lean` proved the combinatorial forking lemma
(`exists_fork_of_card`, `success_card_le_of_dl_hard`): if the adversary
succeeds on more than `q` of the `q^2` pairs, a fork exists, and under
`SchnorrDLHard` the success count is at most `q`. That is an **exact
cardinality** statement — "more than `q`", a hard threshold. What was missing is
the *quantitative* version the literature states: a forger with advantage `ε`
yields a solver with advantage roughly `ε²` (up to the forking loss), so a
non-negligible forger is impossible.

## The random-oracle model

The adversary is the two-stage machine of `SchnorrForking.lean`:
`commit pk tape` fixes the commitment `R` from the randomness alone, and
`respond pk tape R c` answers challenge `c`. In the random-oracle (RO) model the
challenge is the oracle's answer on the adversary's own commitment, so the
oracle's only influence on a fixed tape is the single value `c`. Consequently,
for a fixed tape, acceptance is a predicate on the challenge alone; we record it
as the finset `acceptingChallenges` of challenges that yield an accepting
transcript.

That is the structural fact that makes the second-moment argument work, and it
is *not* an extra hypothesis: it is what the two-stage model already says.

## The reduction

Let `G tape = acceptingChallenges tape`, `N = q` (the challenge-space size) and
`ε = (∑ tape #(G tape)) / N²` (a uniform tape and a uniform challenge). The
**fork probability** is

    φ = (∑ tape #(G tape) * (#(G tape) - 1)) / N³,

i.e. a uniform tape and two independent uniform challenges, both accepting and
distinct. Cauchy–Schwarz gives `∑ #G² ≥ (∑ #G)²/N`, hence

    φ ≥ ε² - ε/N.

Every fork recovers the discrete log (`forking_extractor`), so under
`SchnorrDLHard` the fork probability is zero and therefore `ε ≤ 1/N`: **a
two-stage RO forger succeeds with probability at most `1/q`**. Equivalently, a
forger with advantage `ε` yields a discrete-log solver with advantage at least
`ε² - ε/q` — the standard forking loss.

## Scope and honesty

* This is the **identification / impersonation** game, which is the core of the
  Schnorr-signature UF-CMA proof. A full signature UF-CMA game adds a signing
  oracle; the fork point then moves to the random-oracle query the forgery
  depends on, and the bookkeeping of oracle queries must be added. That
  extension is *not* proved here and is stated as such.
* The random oracle is treated as a **uniform challenge** rather than as a
  function-space probability measure. This is the standard abstraction for the
  two-stage model (the adversary queries the oracle at its own commitment), but
  it does not model an adversary that makes many oracle queries and forks on a
  later one.
* The result is stated for `ZMod q` with `Fact (Nat.Prime q)`, exactly as
  `SchnorrForking.lean`; it is not instantiated in `Ed25519Field`.
* No `sorry`, no new axioms.
-/

namespace LeanFormalization

open Finset

variable (q : ℕ) [Fact (Nat.Prime q)]

/-- The challenge space has `q` elements, and `q ≥ 2` because it is prime. -/
lemma card_zmod_pos : 0 < Fintype.card (ZMod q) := by
  rw [ZMod.card]
  exact (Fact.out : Nat.Prime q).pos

/-- The set of challenges that make a fixed random tape produce an accepting
    Schnorr identification transcript.

    In the random-oracle model this is exactly the adversary's acceptance set:
    the tape fixes `R = f.commit pk tape`, and the oracle's only influence is
    the challenge value `c` fed to `f.respond`. So acceptance, for a fixed tape,
    is a predicate on `c` alone — which is what the second-moment argument
    needs. -/
noncomputable def acceptingChallenges (f : SchnorrAdversary q) (pk tape : ZMod q) :
    Finset (ZMod q) := by
  classical
  exact Finset.univ.filter (fun c => SchnorrAdversary.succeeds q f pk tape c)

/-- The forger's success probability: a uniform random tape and a uniform
    random-oracle challenge. -/
noncomputable def successProbability (f : SchnorrAdversary q) (pk : ZMod q) : ℚ :=
  (∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card) /
    ((Fintype.card (ZMod q) : ℚ) ^ 2)

/-- The fork probability: a uniform random tape and two independent uniform
    challenges, both accepting and distinct. Every such triple is a successful
    fork — same tape, hence same commitment `R`, different challenge — and
    `forking_extractor` turns it into the discrete log. -/
noncomputable def forkProbability (f : SchnorrAdversary q) (pk : ZMod q) : ℚ :=
  (∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
     ((acceptingChallenges q f pk tape).card - 1)) /
    ((Fintype.card (ZMod q) : ℚ) ^ 3)

/-- `↑(k * (k - 1)) = ↑k ^ 2 - ↑k`, the count of ordered distinct pairs. -/
lemma natCast_mul_pred (k : ℕ) : ((k * (k - 1) : ℕ) : ℚ) = (k : ℚ) ^ 2 - (k : ℚ) := by
  have hk : k * (k - 1) = k ^ 2 - k := by
    rw [Nat.mul_sub, pow_two, mul_one]
  rw [hk]
  have hle : (k : ℕ) ≤ k ^ 2 := by nlinarith [sq_nonneg (k : ℤ)]
  rw [Nat.cast_sub hle]
  push_cast
  ring

/-- **The second-moment (RO-forking) inequality.**

    For any family `G : R → Finset C`, writing `ε` for the probability that a
    uniform `R` and a uniform challenge both land in `G`, the probability that
    two independent uniform challenges both land in `G` *and differ* is at least
    `ε² - ε/N`, where `N` is the size of the challenge space.

    This is the quantitative heart of the Pointcheval–Stern / Bellare–Neven
    forking lemma. The only ingredients are Cauchy–Schwarz and the identity
    `k * (k - 1) = k² - k`. -/
theorem fork_ge_secondMoment {R C : Type} [Fintype R] [Fintype C] [DecidableEq R]
    [Nonempty R] [Nonempty C] (G : R → Finset C) :
    ((∑ ρ ∈ Finset.univ, ((G ρ).card * ((G ρ).card - 1) : ℕ)) : ℚ) /
        (((Fintype.card R : ℕ) : ℚ) * ((Fintype.card C : ℕ) : ℚ) ^ 2) ≥
      (((∑ ρ ∈ Finset.univ, ((G ρ).card : ℕ)) : ℚ) /
        (((Fintype.card R : ℕ) : ℚ) * ((Fintype.card C : ℕ) : ℚ))) ^ 2 -
      ((∑ ρ ∈ Finset.univ, ((G ρ).card : ℕ)) : ℚ) /
        (((Fintype.card R : ℕ) : ℚ) * ((Fintype.card C : ℕ) : ℚ) ^ 2) := by
  classical
  set N : ℕ := Fintype.card R with hNdef
  set M : ℕ := Fintype.card C with hMdef
  set S : ℚ := ∑ ρ ∈ Finset.univ, ((G ρ).card : ℚ) with hSdef
  set T : ℚ := ∑ ρ ∈ Finset.univ, ((G ρ).card : ℚ) ^ 2 with hTdef
  have hCS : S ^ 2 ≤ (N : ℚ) * T := by
    have h := Finset.sum_mul_sq_le_sq_mul_sq (s := Finset.univ)
      (f := fun ρ : R => ((G ρ).card : ℚ)) (g := fun _ : R => (1 : ℚ))
    have h' : S ^ 2 ≤ T * (N : ℚ) := by
      simpa [hSdef, hTdef, hNdef, Finset.sum_const, Finset.card_univ, nsmul_eq_mul] using h
    exact le_trans h' (le_of_eq (mul_comm T (N : ℚ)))
  have hsplit : ((∑ ρ ∈ Finset.univ, ((G ρ).card * ((G ρ).card - 1) : ℕ)) : ℚ) = T - S := by
    have hterm : ∀ ρ ∈ Finset.univ,
        (((G ρ).card * ((G ρ).card - 1) : ℕ) : ℚ) =
          ((G ρ).card : ℚ) ^ 2 - ((G ρ).card : ℚ) := by
      intro ρ _
      rw [natCast_mul_pred]
    calc ((∑ ρ ∈ Finset.univ, ((G ρ).card * ((G ρ).card - 1) : ℕ)) : ℚ)
        = ∑ ρ ∈ Finset.univ, (((G ρ).card * ((G ρ).card - 1) : ℕ) : ℚ) := by
            simp only [Nat.cast_mul]
      _ = ∑ ρ ∈ Finset.univ, (((G ρ).card : ℚ) ^ 2 - ((G ρ).card : ℚ)) := by
            exact Finset.sum_congr rfl hterm
      _ = T - S := by
            rw [hTdef, hSdef, ← Finset.sum_sub_distrib]
  rw [hsplit]
  have hNpos : (0 : ℚ) < (N : ℚ) := by
    have h : 0 < Fintype.card R := Fintype.card_pos
    rw [hNdef]; exact_mod_cast h
  have hMpos : (0 : ℚ) < (M : ℚ) := by
    have h : 0 < Fintype.card C := Fintype.card_pos
    rw [hMdef]; exact_mod_cast h
  field_simp
  nlinarith [hCS]

/-- **The quantitative RO-forking inequality.** A forger with success
    probability `ε` yields a fork with probability at least `ε² - ε/N`. -/
theorem forkProbability_ge (f : SchnorrAdversary q) (pk : ZMod q) :
    forkProbability q f pk ≥
      (successProbability q f pk) ^ 2 -
        successProbability q f pk / (Fintype.card (ZMod q) : ℚ) := by
  have h := fork_ge_secondMoment (G := fun tape : ZMod q => acceptingChallenges q f pk tape)
  unfold successProbability forkProbability
  simp only [Nat.cast_sum]
  have hM : (0 : ℚ) < (Fintype.card (ZMod q) : ℚ) := by
    have := card_zmod_pos q; exact_mod_cast this
  have hM3 : (Fintype.card (ZMod q) : ℚ) ^ 3 =
      (Fintype.card (ZMod q) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2 := by ring
  rw [hM3]
  rw [show (Fintype.card (ZMod q) : ℚ) * (Fintype.card (ZMod q) : ℚ) =
      (Fintype.card (ZMod q) : ℚ) ^ 2 by ring] at h
  field_simp at h ⊢
  nlinarith [h]

/-- **Every fork recovers the discrete log.** -/
theorem fork_extraction (f : SchnorrAdversary q) (pk tape c c' : ZMod q)
    (hc : c ∈ acceptingChallenges q f pk tape)
    (hc' : c' ∈ acceptingChallenges q f pk tape) (hne : c ≠ c') :
    Extracts q f pk := by
  classical
  unfold acceptingChallenges at hc hc'
  have hsucc : SchnorrAdversary.succeeds q f pk tape c := (Finset.mem_filter.mp hc).2
  have hsucc' : SchnorrAdversary.succeeds q f pk tape c' := (Finset.mem_filter.mp hc').2
  obtain ⟨R, s, hR, hs, ha⟩ := hsucc
  obtain ⟨R', s', hR', hs', ha'⟩ := hsucc'
  have hRR : R = R' := by
    rw [hR] at hR'
    injection hR'
  subst hRR
  exact forking_extractor q f pk tape c c' R s s' hne hR hs hs' ha ha'

/-- **A positive fork probability produces a concrete fork.** -/
theorem forkEvent_of_forkProbability_pos (f : SchnorrAdversary q) (pk : ZMod q)
    (h : 0 < forkProbability q f pk) :
    ∃ tape c c' : ZMod q, c ∈ acceptingChallenges q f pk tape ∧
      c' ∈ acceptingChallenges q f pk tape ∧ c ≠ c' := by
  classical
  unfold forkProbability at h
  have hden : (0 : ℚ) < (Fintype.card (ZMod q) : ℚ) ^ 3 := by
    have := card_zmod_pos q; positivity
  have hnum : 0 < (∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
      ((acceptingChallenges q f pk tape).card - 1)) := by
    have hpos : (0 : ℚ) < (↑(∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
        ((acceptingChallenges q f pk tape).card - 1)) : ℚ) := by
      have hx : (↑(∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
          ((acceptingChallenges q f pk tape).card - 1)) : ℚ) =
          (↑(∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
            ((acceptingChallenges q f pk tape).card - 1)) : ℚ) /
            (Fintype.card (ZMod q) : ℚ) ^ 3 * (Fintype.card (ZMod q) : ℚ) ^ 3 := by
        field_simp
      rw [hx]
      exact mul_pos h hden
    exact_mod_cast hpos
  have htape : ∃ tape : ZMod q, 0 < (acceptingChallenges q f pk tape).card *
      ((acceptingChallenges q f pk tape).card - 1) := by
    by_contra hcon
    have hnot : ∀ tape : ZMod q, ¬ 0 < (acceptingChallenges q f pk tape).card *
        ((acceptingChallenges q f pk tape).card - 1) := fun t ht => hcon ⟨t, ht⟩
    have hzero : (∑ tape ∈ Finset.univ, (acceptingChallenges q f pk tape).card *
        ((acceptingChallenges q f pk tape).card - 1)) = 0 := by
      exact Finset.sum_eq_zero (fun t _ => by have := hnot t; omega)
    omega
  obtain ⟨tape, ht⟩ := htape
  have hk0 : (acceptingChallenges q f pk tape).card ≠ 0 := by
    intro h0
    rw [h0] at ht
    simp at ht
  have hk1 : 1 ≤ (acceptingChallenges q f pk tape).card := by omega
  have hk2 : 2 ≤ (acceptingChallenges q f pk tape).card := by
    rcases Nat.eq_zero_or_pos (acceptingChallenges q f pk tape).card with h0 | hpos
    · rw [h0] at ht; simp at ht
    · have hz : (0 : ℤ) < ((acceptingChallenges q f pk tape).card : ℤ) *
        (((acceptingChallenges q f pk tape).card : ℤ) - 1) := by
        have hcast : (((acceptingChallenges q f pk tape).card *
            ((acceptingChallenges q f pk tape).card - 1) : ℕ) : ℤ) =
            ((acceptingChallenges q f pk tape).card : ℤ) *
              (((acceptingChallenges q f pk tape).card : ℤ) - 1) := by
          rw [Nat.mul_sub, mul_one]
          have hle : (acceptingChallenges q f pk tape).card ≤
              (acceptingChallenges q f pk tape).card * (acceptingChallenges q f pk tape).card := by
            nlinarith
          rw [Nat.cast_sub hle]
          push_cast
          ring
        rw [← hcast]
        exact_mod_cast ht
      nlinarith
  have hmem : ∃ a : ZMod q, a ∈ acceptingChallenges q f pk tape := by
    by_contra hcon
    have hempty : acceptingChallenges q f pk tape = ∅ :=
      Finset.eq_empty_iff_forall_notMem.mpr (fun x hx => hcon ⟨x, hx⟩)
    rw [hempty, Finset.card_empty] at hk2
    omega
  obtain ⟨a, ha⟩ := hmem
  have hcard_erase : 1 ≤ ((acceptingChallenges q f pk tape).erase a).card := by
    rw [Finset.card_erase_of_mem ha]
    omega
  have hmem' : ∃ b : ZMod q, b ∈ (acceptingChallenges q f pk tape).erase a := by
    by_contra hcon
    have hempty : (acceptingChallenges q f pk tape).erase a = ∅ :=
      Finset.eq_empty_iff_forall_notMem.mpr (fun x hx => hcon ⟨x, hx⟩)
    rw [hempty, Finset.card_empty] at hcard_erase
    omega
  obtain ⟨b, hb⟩ := hmem'
  refine ⟨tape, a, b, ?_, ?_, ?_⟩
  · exact ha
  · exact (Finset.mem_erase.mp hb).2
  · intro hab
    rw [hab] at hb
    exact (Finset.mem_erase.mp hb).1 rfl

/-- **The RO-forking security theorem.** Under discrete-log hardness, a
    two-stage random-oracle adversary succeeds with probability at most `1/q`.

    Equivalently: a forger with advantage `ε` yields a discrete-log solver with
    advantage at least `ε² - ε/q` (the standard forking loss). -/
theorem successProbability_le_of_dl_hard (hhard : SchnorrDLHard q) (f : SchnorrAdversary q)
    (pk : ZMod q) : successProbability q f pk ≤ 1 / (Fintype.card (ZMod q) : ℚ) := by
  classical
  by_contra hgt
  rw [not_le] at hgt
  have hge := forkProbability_ge q f pk
  have hfork : 0 < forkProbability q f pk := by
    have hN : (0 : ℚ) < (Fintype.card (ZMod q) : ℚ) := by
      have := card_zmod_pos q; exact_mod_cast this
    have hinv : (0 : ℚ) < 1 / (Fintype.card (ZMod q) : ℚ) := by positivity
    have heps : 0 < successProbability q f pk := by linarith
    have hquad : 0 < successProbability q f pk ^ 2 -
        successProbability q f pk / (Fintype.card (ZMod q) : ℚ) := by
      have h1 : (0 : ℚ) < successProbability q f pk - 1 / (Fintype.card (ZMod q) : ℚ) := by
        linarith
      have h2 : successProbability q f pk ^ 2 -
          successProbability q f pk / (Fintype.card (ZMod q) : ℚ) =
          successProbability q f pk *
            (successProbability q f pk - 1 / (Fintype.card (ZMod q) : ℚ)) := by
        field_simp
      rw [h2]
      exact mul_pos heps h1
    linarith
  obtain ⟨tape, c, c', hc, hc', hne⟩ := forkEvent_of_forkProbability_pos q f pk hfork
  have hEX : Extracts q f pk := fork_extraction q f pk tape c c' hc hc' hne
  let adv : ZMod q → Option (ZMod q) :=
    fun pk' => if h : Extracts q f pk' then some (Classical.choose h) else none
  have hch : Classical.choose hEX = pk := (Classical.choose_spec hEX).1.symm
  have hrun : adv pk = some pk := by
    simp only [adv]
    rw [dif_pos hEX, hch]
  exact hhard adv pk hrun

/-- **The forking loss.** A forger with advantage `ε` yields a discrete-log
    solver with advantage at least `ε² - ε/N`, for the challenge space of size
    `N`. This is the quantitative statement the reduction is usually quoted as. -/
theorem dl_solver_advantage_of_forger (f : SchnorrAdversary q) (pk : ZMod q) :
    forkProbability q f pk ≥
      (successProbability q f pk) ^ 2 -
        successProbability q f pk / (Fintype.card (ZMod q) : ℚ) :=
  forkProbability_ge q f pk

/-- **Tightness of the `1/N` bound.** The threshold is attained: the adversary
    that answers only the challenge `0` succeeds on exactly `1/N` of the
    `(tape, challenge)` pairs and never forks. So `successProbability` cannot be
    bounded below `1/N`. -/
theorem successProbability_eq_one_div_card (pk : ZMod q) :
    ∃ f : SchnorrAdversary q, successProbability q f pk = 1 / (Fintype.card (ZMod q) : ℚ) := by
  classical
  let f : SchnorrAdversary q :=
    { commit := fun _ _ => some 0, respond := fun _ _ _ c => if c = 0 then some 0 else none }
  refine ⟨f, ?_⟩
  unfold successProbability acceptingChallenges
  have hfilter : ∀ tape : ZMod q,
      (Finset.univ.filter (fun c => SchnorrAdversary.succeeds q f pk tape c)) = {0} := by
    intro tape
    ext c
    simp only [Finset.mem_filter, Finset.mem_singleton]
    constructor
    · rintro ⟨_, R, s, hR, hs, ha⟩
      simp only [f] at hs
      by_cases hc : c = 0
      · exact hc
      · rw [if_neg hc] at hs
        cases hs
    · intro hc0
      subst hc0
      refine ⟨Finset.mem_univ 0, 0, 0, rfl, ?_, by simp [schnorrAccept]⟩
      change (if (0 : ZMod q) = 0 then some (0 : ZMod q) else none) = some (0 : ZMod q)
      rw [if_pos rfl]
  rw [Finset.sum_congr rfl (fun t _ => by rw [hfilter t]), Finset.sum_const, Finset.card_univ,
    nsmul_eq_mul, Finset.card_singleton]
  push_cast
  field_simp

end LeanFormalization
