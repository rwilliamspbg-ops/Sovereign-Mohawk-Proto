/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.SchnorrUF_CMA

/-!
# A simplified UF-CMA game for Schnorr signatures, with a signing oracle

`SchnorrUF_CMA.lean` proved the random-oracle forking reduction for the
**identification / impersonation** game: a two-stage adversary whose commitment
is fixed by its random tape, and the security statement `ε ≤ 1/N` under
`SchnorrDLHard`.

This file lifts that to the **signature UF-CMA game** — the game a signature
scheme is actually asked to satisfy — inside the same simplified random-oracle
abstraction. The additions are exactly the two things distinguishing UF-CMA
from impersonation:

* a **signing oracle**, which the adversary may query and which answers with
  honest signatures `(R, r + H(R, pk, m)·sk)`; and
* a **freshness (not-queried) condition**: the forgery must be on a message the
  oracle was never asked.

## The model

The prefix is `(tape, sigs)` — the adversary's random tape and the signing
oracle's transcript. Following `SchnorrAdversary`, the adversary is **two-stage**:
the prefix fixes the forgery message `m` and the nonce point `R`, and only the
response depends on the forgery challenge `c`, the random oracle's answer at the
hash query the forgery depends on. That is what makes the fork's "same
commitment" automatic, exactly as in the identification game.

The number of signing queries is a fixed `k`, so the prefix space is finite and
the second-moment argument of `SchnorrUF_CMA.lean` applies unchanged.

## Results

* `ufcma_forkProbability_ge` / `ufcma_dl_solver_advantage_of_forger`:
  with `ε` the UF-CMA success probability and `φ` the fork probability,
  `φ ≥ ε² - ε/N`.
* `ufcma_fork_extraction`: a fork yields two accepting signatures on the *same*
  message with the same nonce point and different challenges, which is exactly
  `Extracts`.
* `ufcma_security_of_dl_hard`: under `SchnorrDLHard`, **`ε ≤ 1/N`**.

## Scope and honesty

* The random oracle is still a **uniform challenge**, not a function-space
  probability measure. The model does not track *which* oracle query the forgery
  depends on, nor how many queries the adversary makes. That is the same
  abstraction as `SchnorrUF_CMA.lean`, now carrying a signing oracle; the
  `ε²/q_H` loss of the full Pointcheval–Stern argument is therefore **not**
  recovered here.
* The signing oracle is **honest**, and its transcript is abstracted as `k`
  independent signatures. The adversary's choice of queries does not influence
  the answers beyond that.
* The scheme is exponent-model Schnorr (`pk = sk`, `R = r`, `s = r + h·sk`),
  not Ed25519's concrete group; `Ed25519VerificationEquation` supplies the
  bridge.
* No `sorry`, no new axioms.
-/

namespace LeanFormalization

open Finset

variable (q : ℕ) [Fact (Nat.Prime q)]

variable (k : ℕ)

/-- Messages are abstracted to `ZMod q`; the binding to the message is carried by
    the random-oracle challenge. -/
abbrev Message (q : ℕ) := ZMod q

/-- An honest Schnorr signature on `m` with nonce point `R = r`:
    `s = r + H(R, pk, m)·sk`.

    Encoded as a triple so that `Fintype`/`DecidableEq` come from `Prod`. -/
abbrev Signature (q : ℕ) := Message q × ZMod q × ZMod q

namespace Signature

def message (σ : Signature q) : Message q := σ.1
def noncePoint (σ : Signature q) : ZMod q := σ.2.1
def response (σ : Signature q) : ZMod q := σ.2.2

end Signature

/-- The signing oracle's transcript: `k` honest signatures. -/
abbrev SigningTranscript (q k : ℕ) := Fin k → Signature q

/-- The adversary's prefix: its random tape and the signing oracle's transcript. -/
abbrev UFCMAPrefix (q k : ℕ) := ZMod q × SigningTranscript q k

/-- The honest response on a fresh nonce `r` under the oracle's challenge `h`. -/
def honestResponse (sk r h : ZMod q) : ZMod q := r + h * sk

omit [Fact (Nat.Prime q)] in
/-- **Honest signatures verify.** In the exponent model `pk = sk`, the signature
    `(R = r, s = r + h·sk)` satisfies `s = R + h·pk`. -/
theorem honestResponse_accepts (sk r h : ZMod q) :
    schnorrAccept q sk h r (honestResponse q sk r h) := by
  simp [schnorrAccept, honestResponse]

/-- A two-stage UF-CMA adversary with a signing oracle.

    The prefix `(tape, sigs)` fixes the forgery message `m` and the nonce point
    `R`; only the response depends on the forgery challenge `c`. This is the
    UF-CMA analogue of `SchnorrAdversary`'s two-stage split, and it is what
    makes the fork's "same commitment" automatic. -/
structure UFCMAAdversary where
  message : ZMod q → ZMod q → SigningTranscript q k → Message q
  noncePoint : ZMod q → ZMod q → SigningTranscript q k → ZMod q
  respond : ZMod q → ZMod q → SigningTranscript q k → ZMod q → Option (ZMod q)

/-- **The UF-CMA forgery condition.** The adversary forges on
    `(tape, sigs, c)` when it outputs a signature that verifies under the
    challenge `c` on a message the oracle was never asked. -/
def ufcmaForges (adv : UFCMAAdversary q k) (pk tape : ZMod q)
    (sigs : SigningTranscript q k) (c : ZMod q) : Prop :=
  ∃ s, adv.respond pk tape sigs c = some s ∧
    schnorrAccept q pk c (adv.noncePoint pk tape sigs) s ∧
    ∀ i, (sigs i).message ≠ adv.message pk tape sigs

/-- The challenges that make a fixed prefix forge. -/
noncomputable def ufcmaAcceptingChallenges (adv : UFCMAAdversary q k) (pk tape : ZMod q)
    (sigs : SigningTranscript q k) : Finset (ZMod q) := by
  classical
  exact Finset.univ.filter (fun c => ufcmaForges q k adv pk tape sigs c)

/-- The UF-CMA success probability: a uniform prefix and a uniform forgery
    challenge. -/
noncomputable def ufcmaSuccessProbability (adv : UFCMAAdversary q k) (pk : ZMod q) : ℚ :=
  (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card) /
    ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ))

/-- The fork probability: a uniform prefix and two independent uniform forgery
    challenges, both forging and distinct. -/
noncomputable def ufcmaForkProbability (adv : UFCMAAdversary q k) (pk : ZMod q) : ℚ :=
  (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
     ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) /
    ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2)

/-- **The quantitative UF-CMA forking inequality.** `φ ≥ ε² - ε/N`. -/
theorem ufcma_forkProbability_ge (adv : UFCMAAdversary q k) (pk : ZMod q) :
    ufcmaForkProbability q k adv pk ≥
      (ufcmaSuccessProbability q k adv pk) ^ 2 -
        ufcmaSuccessProbability q k adv pk / (Fintype.card (ZMod q) : ℚ) := by
  have h := fork_ge_secondMoment (R := UFCMAPrefix q k) (C := ZMod q)
    (G := fun p => ufcmaAcceptingChallenges q k adv pk p.1 p.2)
  have hbridge :
      (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
          (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card : ℚ) /
        ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ)) /
        (Fintype.card (ZMod q) : ℚ) =
      (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
          (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card : ℚ) /
        ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2) := by
    field_simp
  unfold ufcmaSuccessProbability ufcmaForkProbability
  simp only [Nat.cast_sum]
  rw [hbridge]
  exact h

/-- **The forking loss**, in the UF-CMA game. -/
theorem ufcma_dl_solver_advantage_of_forger (adv : UFCMAAdversary q k) (pk : ZMod q) :
    ufcmaForkProbability q k adv pk ≥
      (ufcmaSuccessProbability q k adv pk) ^ 2 -
        ufcmaSuccessProbability q k adv pk / (Fintype.card (ZMod q) : ℚ) :=
  ufcma_forkProbability_ge q k adv pk

/-- The identification-game adversary induced by fixing a UF-CMA prefix. -/
noncomputable def ufcmaInducedAdversary (adv : UFCMAAdversary q k) (tape : ZMod q)
    (sigs : SigningTranscript q k) : SchnorrAdversary q where
  commit := fun pk _ => some (adv.noncePoint pk tape sigs)
  respond := fun pk _ _ c => adv.respond pk tape sigs c

/-- **A UF-CMA fork recovers the key.** Two distinct forgery challenges that both
    forge for the same prefix give two accepting signatures on the same message,
    with the same nonce point and different challenges. -/
theorem ufcma_fork_extraction (adv : UFCMAAdversary q k) (pk tape : ZMod q)
    (sigs : SigningTranscript q k) (c c' : ZMod q)
    (hc : c ∈ ufcmaAcceptingChallenges q k adv pk tape sigs)
    (hc' : c' ∈ ufcmaAcceptingChallenges q k adv pk tape sigs) (hne : c ≠ c') :
    Extracts q (ufcmaInducedAdversary q k adv tape sigs) pk := by
  classical
  obtain ⟨s, hs, ha, _⟩ := (Finset.mem_filter.mp hc).2
  obtain ⟨s', hs', ha', _⟩ := (Finset.mem_filter.mp hc').2
  exact forking_extractor q (ufcmaInducedAdversary q k adv tape sigs) pk tape c c'
    (adv.noncePoint pk tape sigs) s s' hne rfl hs hs' ha ha'

/-- **The UF-CMA security theorem.** Under discrete-log hardness, no UF-CMA
    adversary succeeds with probability greater than `1/N`. -/
theorem ufcma_security_of_dl_hard (hhard : SchnorrDLHard q) (adv : UFCMAAdversary q k)
    (pk : ZMod q) : ufcmaSuccessProbability q k adv pk ≤ 1 / (Fintype.card (ZMod q) : ℚ) := by
  classical
  by_contra hgt
  rw [not_le] at hgt
  have hN : (0 : ℚ) < (Fintype.card (ZMod q) : ℚ) := by
    have := card_zmod_pos q; exact_mod_cast this
  have hinv : (0 : ℚ) < 1 / (Fintype.card (ZMod q) : ℚ) := by positivity
  have heps : 0 < ufcmaSuccessProbability q k adv pk := by linarith
  have hquad : 0 < ufcmaSuccessProbability q k adv pk ^ 2 -
      ufcmaSuccessProbability q k adv pk / (Fintype.card (ZMod q) : ℚ) := by
    have h1 : (0 : ℚ) < ufcmaSuccessProbability q k adv pk - 1 / (Fintype.card (ZMod q) : ℚ) := by
      linarith
    have h2 : ufcmaSuccessProbability q k adv pk ^ 2 -
        ufcmaSuccessProbability q k adv pk / (Fintype.card (ZMod q) : ℚ) =
        ufcmaSuccessProbability q k adv pk *
          (ufcmaSuccessProbability q k adv pk - 1 / (Fintype.card (ZMod q) : ℚ)) := by
      field_simp
    rw [h2]
    exact mul_pos heps h1
  have hge := ufcma_forkProbability_ge q k adv pk
  have hfork : 0 < ufcmaForkProbability q k adv pk := by linarith
  -- a positive fork probability produces a concrete fork
  have hden : (0 : ℚ) < (Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2 := by
    have := card_zmod_pos q
    have hpre : 0 < Fintype.card (UFCMAPrefix q k) := by
      rw [← Finset.card_univ]
      exact Finset.card_pos.mpr (Finset.univ_nonempty (α := UFCMAPrefix q k))
    positivity
  have hnum : 0 < (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
      ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) := by
    have hpos : (0 : ℚ) < (↑(∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
        ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) : ℚ) := by
      have hx : (↑(∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
          ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) : ℚ) =
          (↑(∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
            ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) : ℚ) /
            ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2) *
            ((Fintype.card (UFCMAPrefix q k) : ℚ) * (Fintype.card (ZMod q) : ℚ) ^ 2) := by
        field_simp
      rw [hx]
      exact mul_pos hfork hden
    exact_mod_cast hpos
  have hpref : ∃ p : UFCMAPrefix q k,
      0 < (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
        ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1) := by
    by_contra hcon
    have hnot : ∀ p : UFCMAPrefix q k, ¬ 0 < (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
        ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1) := fun p hp => hcon ⟨p, hp⟩
    have hzero : (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix q k)),
      (ufcmaAcceptingChallenges q k adv pk p.1 p.2).card *
        ((ufcmaAcceptingChallenges q k adv pk p.1 p.2).card - 1)) = 0 := by
      exact Finset.sum_eq_zero (fun t _ => by have := hnot t; omega)
    omega
  obtain ⟨p, hp⟩ := hpref
  obtain ⟨tape, sigs⟩ := p
  have hk2 : 2 ≤ (ufcmaAcceptingChallenges q k adv pk tape sigs).card := by
    rcases Nat.eq_zero_or_pos (ufcmaAcceptingChallenges q k adv pk tape sigs).card with h0 | hpos
    · rw [h0] at hp; simp at hp
    · have hz : (0 : ℤ) < ((ufcmaAcceptingChallenges q k adv pk tape sigs).card : ℤ) *
        (((ufcmaAcceptingChallenges q k adv pk tape sigs).card : ℤ) - 1) := by
        have hcast : (((ufcmaAcceptingChallenges q k adv pk tape sigs).card *
            ((ufcmaAcceptingChallenges q k adv pk tape sigs).card - 1) : ℕ) : ℤ) =
            ((ufcmaAcceptingChallenges q k adv pk tape sigs).card : ℤ) *
              (((ufcmaAcceptingChallenges q k adv pk tape sigs).card : ℤ) - 1) := by
          rw [Nat.mul_sub, mul_one]
          have hle : (ufcmaAcceptingChallenges q k adv pk tape sigs).card ≤
              (ufcmaAcceptingChallenges q k adv pk tape sigs).card *
                (ufcmaAcceptingChallenges q k adv pk tape sigs).card := by nlinarith
          rw [Nat.cast_sub hle]
          push_cast
          ring
        rw [← hcast]
        exact_mod_cast hp
      nlinarith
  have hmem : ∃ a : ZMod q, a ∈ ufcmaAcceptingChallenges q k adv pk tape sigs := by
    by_contra hcon
    have hempty : ufcmaAcceptingChallenges q k adv pk tape sigs = ∅ :=
      Finset.eq_empty_iff_forall_notMem.mpr (fun x hx => hcon ⟨x, hx⟩)
    rw [hempty, Finset.card_empty] at hk2
    omega
  obtain ⟨a, ha⟩ := hmem
  have hcard_erase : 1 ≤ ((ufcmaAcceptingChallenges q k adv pk tape sigs).erase a).card := by
    rw [Finset.card_erase_of_mem ha]
    omega
  have hmem' : ∃ b : ZMod q, b ∈ (ufcmaAcceptingChallenges q k adv pk tape sigs).erase a := by
    by_contra hcon
    have hempty : (ufcmaAcceptingChallenges q k adv pk tape sigs).erase a = ∅ :=
      Finset.eq_empty_iff_forall_notMem.mpr (fun x hx => hcon ⟨x, hx⟩)
    rw [hempty, Finset.card_empty] at hcard_erase
    omega
  obtain ⟨b, hb⟩ := hmem'
  have hEX : Extracts q (ufcmaInducedAdversary q k adv tape sigs) pk :=
    ufcma_fork_extraction q k adv pk tape sigs a b ha (Finset.mem_erase.mp hb).2
      (by
        intro hab
        rw [hab] at hb
        exact (Finset.mem_erase.mp hb).1 rfl)
  let advDL : ZMod q → Option (ZMod q) :=
    fun pk' => if h : Extracts q (ufcmaInducedAdversary q k adv tape sigs) pk'
      then some (Classical.choose h) else none
  have hch : Classical.choose hEX = pk := (Classical.choose_spec hEX).1.symm
  have hrun : advDL pk = some pk := by
    simp only [advDL]
    rw [dif_pos hEX, hch]
  exact hhard advDL pk hrun

/-- **Tightness of the UF-CMA bound.** With no signing queries (`k = 0`) the
    adversary that answers only the challenge `0` has success probability
    exactly `1/N`, so `ufcma_security_of_dl_hard` cannot be improved. -/
theorem ufcmaSuccessProbability_eq_one_div_card (pk : ZMod q) :
    ∃ adv : UFCMAAdversary q 0,
      ufcmaSuccessProbability q 0 adv pk = 1 / (Fintype.card (ZMod q) : ℚ) := by
  classical
  let adv : UFCMAAdversary q 0 :=
    { message := fun _ _ _ => 0, noncePoint := fun _ _ _ => 0,
      respond := fun _ _ _ c => if c = 0 then some 0 else none }
  refine ⟨adv, ?_⟩
  have hchallenges : ∀ (t : ZMod q) (sigs : SigningTranscript q 0),
      ufcmaAcceptingChallenges q 0 adv pk t sigs = {0} := by
    intro t sigs
    ext c
    simp only [ufcmaAcceptingChallenges, ufcmaForges, adv, Finset.mem_filter,
      Finset.mem_singleton, Finset.mem_univ, schnorrAccept]
    by_cases hc : c = 0
    · simp [hc]
    · simp [hc]
  unfold ufcmaSuccessProbability
  rw [Finset.sum_congr rfl (fun p _ => by rw [hchallenges p.1 p.2]), Finset.sum_const,
    Finset.card_univ, nsmul_eq_mul, Finset.card_singleton]
  push_cast
  field_simp

/-- **Negative control: the freshness condition is load-bearing.** For `k > 0`
    there is a prefix on which the adversary produces an accepting signature on
    challenge `0`, yet `ufcmaForges` is false because the oracle was asked that
    very message. Dropping the not-queried condition would raise the adversary's
    success probability. -/
theorem ufcma_freshness_is_load_bearing (pk : ZMod q) (k : ℕ) (hk : 0 < k) :
    ∃ (adv : UFCMAAdversary q k) (t : ZMod q) (sigs : SigningTranscript q k)
      (c : ZMod q),
      adv.respond pk t sigs c = some 0 ∧
        schnorrAccept q pk c (adv.noncePoint pk t sigs) 0 ∧
        ¬ ufcmaForges q k adv pk t sigs c := by
  classical
  let adv : UFCMAAdversary q k :=
    { message := fun _ _ _ => 0, noncePoint := fun _ _ _ => 0,
      respond := fun _ _ _ c => if c = 0 then some 0 else none }
  let sigs : SigningTranscript q k := fun _ => ((0 : ZMod q), (0 : ZMod q), (0 : ZMod q))
  refine ⟨adv, 0, sigs, 0, ?_, ?_, ?_⟩
  · simp only [adv]
    simp
  · simp only [adv]
    simp [schnorrAccept]
  · rintro ⟨s, _, _, hfresh⟩
    have hneq : (sigs ⟨0, hk⟩).message ≠ adv.message pk 0 sigs := hfresh ⟨0, hk⟩
    dsimp only [adv, sigs] at hneq
    exact hneq rfl

end LeanFormalization
