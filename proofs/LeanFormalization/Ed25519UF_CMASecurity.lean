/-
Copyright (c) 2026 Sovereign Mohawk contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sovereign Mohawk contributors
-/
import Mathlib
import LeanFormalization.Ed25519VerificationEquation
import LeanFormalization.SchnorrUF_CMAWithOracle

/-!
# The crypto capstone: Ed25519 UF-CMA in the exponent abstraction

This file composes the four proved pieces of the cryptographic package into a
single security statement about the **real** Ed25519 verification equation:

1. `Ed25519GroupLaws affineBase` — the explicit, finite bundle of curve-model
   hypotheses (row 26);
2. `verificationEquation_iff_ModEq` — the transfer from the curve equation to
   the exponent equation;
3. `ufcma_security_of_dl_hard` — the random-oracle forking reduction for the
   UF-CMA game with a signing oracle (row 32);
4. `SchnorrDLHard dlL` — the discrete-logarithm hardness assumption.

## The transfer

`ed25519Accept` is the curve-level acceptance predicate: `S·B = R + h·A` with
`A = a·B` and `R = r·B`. `ed25519Accept_iff_schnorrAccept` proves it is
**equivalent** to the exponent-model Schnorr acceptance predicate at
`pk = a mod L`, `c = h mod L`, `R = r mod L`, `s = S mod L`. This is
`verificationEquation_iff_ModEq` composed with the `ZMod`/`Nat.ModEq` bridge;
it is what makes the exponent-model UF-CMA bound a statement about Ed25519.

## The capstone

`Ed25519UFCMAAdversary k` is the UF-CMA adversary of row 32 equipped with the
nonce exponent that fixes the nonce point `R = r·B`. Its success probability
`ed25519SuccessProbability` is *equal* to the exponent-model
`ufcmaSuccessProbability` (the acceptance sets correspond pointwise by the
transfer), and therefore `ed25519_ufcma_security` concludes:

    under Ed25519GroupLaws affineBase and SchnorrDLHard dlL,
    ed25519SuccessProbability adv a ≤ 1 / dlL.

## Scope and honesty

* The group laws on `AffinePoint` are **assumed**, not proved — they are a
  modeling choice about the unaudited `affineScalarMulImpl` / `affineAdd`.
* The random oracle is the **uniform-challenge** abstraction of row 32, not a
  function-space measure; the `ε²/q_H` loss of full Pointcheval–Stern is not
  recovered.
* The signing oracle is honest and abstracted as `k` independent signatures.
* The hash function is not modelled; `h` is an abstract challenge.
-/

namespace LeanFormalization

open Finset

set_option maxRecDepth 100000

variable {k : ℕ}

/-- `dlL` is positive, so `ZMod dlL` is a nontrivial ring and has a `Fintype`. -/
instance dlL_NeZero : NeZero dlL := ⟨by unfold dlL ed25519L; positivity⟩

/-- The curve-level acceptance predicate: the real Ed25519 verification
    equation for the public key `A = a·B`, the nonce point `R = r·B`, response
    `S` and challenge `h`. -/
def ed25519Accept (B : AffinePoint) (a r S h : Nat) : Prop :=
  Ed25519VerificationEquation B (affineScalarMulImpl a B) (affineScalarMulImpl r B) S h

/-- **The transfer.** Under the group laws, the curve-level Ed25519 acceptance
    predicate is exactly the exponent-model Schnorr acceptance predicate at the
    corresponding residues. This is `verificationEquation_iff_ModEq` composed
    with the `ZMod` / `Nat.ModEq` bridge. -/
theorem ed25519Accept_iff_schnorrAccept (B : AffinePoint) (hlaws : Ed25519GroupLaws B)
    (hp : Fact (Nat.Prime dlL)) (a r S h : Nat) :
    ed25519Accept B a r S h ↔
      schnorrAccept dlL ((a % dlL : Nat) : ZMod dlL) ((h % dlL : Nat) : ZMod dlL)
        ((r % dlL : Nat) : ZMod dlL) ((S % dlL : Nat) : ZMod dlL) := by
  unfold ed25519Accept schnorrAccept
  rw [verificationEquation_iff_ModEq B hlaws a r S h
    (affineScalarMulImpl a B) (affineScalarMulImpl r B) rfl rfl]
  have hR : ((r % dlL : Nat) : ZMod dlL) + ((h % dlL : Nat) : ZMod dlL) *
      ((a % dlL : Nat) : ZMod dlL) = (((r + h * a) % dlL : Nat) : ZMod dlL) := by
    rw [ZMod.natCast_mod, ZMod.natCast_mod, ZMod.natCast_mod, ZMod.natCast_mod]
    push_cast
    simp
  rw [hR, ZMod.natCast_mod, ZMod.natCast_mod, ZMod.natCast_eq_natCast_iff]

/-- The exponent-model acceptance at `(a mod L, c, r mod L, s mod L)` is exactly
    the curve-level acceptance at challenge `c.val`. -/
theorem schnorrAccept_at (hlaws : Ed25519GroupLaws affineBase) (hp : Fact (Nat.Prime dlL))
    (a r s : Nat) (c : ZMod dlL) :
    schnorrAccept dlL ((a % dlL : Nat) : ZMod dlL) c ((r % dlL : Nat) : ZMod dlL)
      ((s % dlL : Nat) : ZMod dlL) ↔
      ed25519Accept affineBase a r s c.val := by
  rw [ed25519Accept_iff_schnorrAccept affineBase hlaws hp a r s c.val]
  have hc : ((c.val % dlL : Nat) : ZMod dlL) = c := by simp
  rw [hc]

/-- A curve-level Ed25519 UF-CMA adversary: the exponent adversary of row 32,
    plus the nonce exponent that fixes the nonce point `R = r·B`. The `hnonce`
    field pins the exponent adversary's nonce point to that exponent, which is
    what makes the transfer applicable. -/
structure Ed25519UFCMAAdversary k where
  exponent : UFCMAAdversary dlL k
  nonceExponent : ZMod dlL → SigningTranscript dlL k → Nat
  hnonce : ∀ (pk : ZMod dlL) (tape : ZMod dlL) (sigs : SigningTranscript dlL k),
    exponent.noncePoint pk tape sigs = ((nonceExponent tape sigs % dlL : Nat) : ZMod dlL)

/-- The curve-level UF-CMA forgery condition: an accepting Ed25519 signature on
    a message the oracle was never asked. -/
def ed25519Forges (adv : Ed25519UFCMAAdversary k) (a : Nat) (tape : ZMod dlL)
    (sigs : SigningTranscript dlL k) (c : ZMod dlL) : Prop :=
  ∃ S : Nat, adv.exponent.respond ((a % dlL : Nat) : ZMod dlL) tape sigs c =
      some ((S % dlL : Nat) : ZMod dlL) ∧
    ed25519Accept affineBase a (adv.nonceExponent tape sigs) S c.val ∧
    ∀ i, (sigs i).message ≠ adv.exponent.message ((a % dlL : Nat) : ZMod dlL) tape sigs

/-- The challenges that make a fixed curve-level prefix forge. -/
noncomputable def ed25519AcceptingChallenges (adv : Ed25519UFCMAAdversary k) (a : Nat)
    (tape : ZMod dlL) (sigs : SigningTranscript dlL k) : Finset (ZMod dlL) := by
  classical
  exact Finset.univ.filter (fun c => ed25519Forges adv a tape sigs c)

/-- The curve-level UF-CMA success probability. -/
noncomputable def ed25519SuccessProbability (adv : Ed25519UFCMAAdversary k) (a : Nat) : ℚ :=
  (∑ p ∈ (Finset.univ : Finset (UFCMAPrefix dlL k)),
      (ed25519AcceptingChallenges adv a p.1 p.2).card) /
    ((Fintype.card (UFCMAPrefix dlL k) : ℚ) * (Fintype.card (ZMod dlL) : ℚ))

/-- **The curve-level forgery condition is the exponent-level one.** Pointwise
    equivalence of `ed25519Forges` and `ufcmaForges`, via the transfer. -/
theorem ed25519Forges_iff_ufcmaForges (hlaws : Ed25519GroupLaws affineBase)
    (hp : Fact (Nat.Prime dlL)) (adv : Ed25519UFCMAAdversary k) (a : Nat) (tape : ZMod dlL)
    (sigs : SigningTranscript dlL k) (c : ZMod dlL) :
    ed25519Forges adv a tape sigs c ↔
      ufcmaForges dlL k adv.exponent ((a % dlL : Nat) : ZMod dlL) tape sigs c := by
  unfold ed25519Forges ufcmaForges
  constructor
  · rintro ⟨S, hs, ha, hfresh⟩
    refine ⟨((S % dlL : Nat) : ZMod dlL), hs, ?_, hfresh⟩
    rw [adv.hnonce ((a % dlL : Nat) : ZMod dlL) tape sigs]
    exact (schnorrAccept_at hlaws hp a (adv.nonceExponent tape sigs) S c).mpr ha
  · rintro ⟨s, hs, ha, hfresh⟩
    refine ⟨s.val, ?_, ?_, hfresh⟩
    · have hconv : ((s.val % dlL : Nat) : ZMod dlL) = s := by simp
      rw [hconv]
      exact hs
    · refine (schnorrAccept_at hlaws hp a (adv.nonceExponent tape sigs) s.val c).mp ?_
      unfold schnorrAccept at ha ⊢
      rw [adv.hnonce ((a % dlL : Nat) : ZMod dlL) tape sigs] at ha
      rw [show ((s.val % dlL : Nat) : ZMod dlL) = s from by simp]
      exact ha

/-- The curve-level and exponent-level success probabilities coincide, because
    the acceptance sets correspond pointwise. -/
theorem ed25519SuccessProbability_eq (hlaws : Ed25519GroupLaws affineBase)
    (hp : Fact (Nat.Prime dlL)) (adv : Ed25519UFCMAAdversary k) (a : Nat) :
    ed25519SuccessProbability adv a =
      ufcmaSuccessProbability dlL k adv.exponent ((a % dlL : Nat) : ZMod dlL) := by
  have hset : ∀ p : UFCMAPrefix dlL k,
      ed25519AcceptingChallenges adv a p.1 p.2 =
        ufcmaAcceptingChallenges dlL k adv.exponent ((a % dlL : Nat) : ZMod dlL) p.1 p.2 := by
    intro p
    classical
    ext c
    change c ∈ Finset.univ.filter (fun c => ed25519Forges adv a p.1 p.2 c) ↔
      c ∈ Finset.univ.filter
        (fun c => ufcmaForges dlL k adv.exponent ((a % dlL : Nat) : ZMod dlL) p.1 p.2 c)
    simp only [Finset.mem_filter, Finset.mem_univ, true_and]
    exact ed25519Forges_iff_ufcmaForges hlaws hp adv a p.1 p.2 c
  unfold ed25519SuccessProbability ufcmaSuccessProbability
  rw [Finset.sum_congr rfl (fun p _ => by rw [hset p])]

/-- **The capstone.** Composing the Ed25519 group laws, the verification
    equation ↔ exponent transfer, the random-oracle forking reduction for the
    UF-CMA game, and discrete-log hardness:

    under `Ed25519GroupLaws affineBase` and `SchnorrDLHard dlL`, no curve-level
    UF-CMA adversary succeeds with probability greater than `1/dlL`. -/
theorem ed25519_ufcma_security (hp : Fact (Nat.Prime dlL))
    (hlaws : Ed25519GroupLaws affineBase) (hhard : SchnorrDLHard dlL)
    (adv : Ed25519UFCMAAdversary k) (a : Nat) :
    ed25519SuccessProbability adv a ≤ 1 / (Fintype.card (ZMod dlL) : ℚ) := by
  rw [ed25519SuccessProbability_eq hlaws hp adv a]
  exact ufcma_security_of_dl_hard dlL k hhard adv.exponent ((a % dlL : Nat) : ZMod dlL)

/-- **Curve-level fork extraction.** Two curve-level accepting signatures that
    share the nonce point and differ in the challenge recover the secret key.
    This is the capstone's fork content at the level of the real verification
    equation, via `ed25519_two_equations_recover`. -/
theorem ed25519_fork_recovers (hp : Fact (Nat.Prime dlL))
    (hlaws : Ed25519GroupLaws affineBase) (adv : Ed25519UFCMAAdversary k) (a : Nat)
    (tape : ZMod dlL) (sigs : SigningTranscript dlL k) (c c' : ZMod dlL)
    (hc : ed25519Forges adv a tape sigs c) (hc' : ed25519Forges adv a tape sigs c')
    (hne : c ≠ c') :
    ∃ S S' : Nat, (recoverSecret hp S S' c.val c'.val) % dlL = a % dlL := by
  obtain ⟨S, hS, ha, hfresh⟩ := hc
  obtain ⟨S', hS', ha', hfresh'⟩ := hc'
  refine ⟨S, S', ?_⟩
  have hne' : ¬ Nat.ModEq dlL c.val c'.val := by
    intro hmod
    apply hne
    have h : (c.val : ZMod dlL) = (c'.val : ZMod dlL) :=
      (ZMod.natCast_eq_natCast_iff c.val c'.val dlL).mpr hmod
    rw [ZMod.natCast_zmod_val, ZMod.natCast_zmod_val] at h
    exact h
  exact ed25519_two_equations_recover hp hlaws a (adv.nonceExponent tape sigs)
    (affineScalarMulImpl a affineBase) (affineScalarMulImpl (adv.nonceExponent tape sigs) affineBase)
    c.val c'.val S S' rfl rfl ha ha' hne'

end LeanFormalization
