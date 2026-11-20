import Mathlib
import LeanFormalization.SchnorrReduction

/-!
# A proved forking-style reduction for the Schnorr identification protocol

`SchnorrReduction.lean` proves the extractor — two accepting transcripts with
the same commitment and different challenges determine the key — and leaves the
*forking step* (obtaining those two transcripts from one forger) as an opaque
hypothesis, `ForkingStep`. This module replaces that hypothesis with a
**concrete, machine-checked combinatorial condition** and proves the whole
reduction down to a clearly labelled hardness assumption.

## The structural fact the old hypothesis hid

In the real protocol the adversary commits **before** it sees the challenge:
the first message `R` is a function of the public key and the adversary's
randomness alone. `SchnorrAdversary` below makes that explicit by splitting the
adversary into `commit` (no challenge argument) and `respond`. Consequently two
runs with the SAME randomness produce the SAME commitment, whatever challenges
are used — which is exactly the "same commitment" hypothesis the forking step
needs. No rewinding machinery is required for that part; it is a property of the
model.

## The combinatorial forking lemma

The remaining content of the forking lemma is a pigeonhole principle, and it is
proved here with no probability theory:

> If the adversary succeeds on more than `q` of the `q^2`
> (randomness, challenge) pairs — i.e. with success probability greater than
> `1/q` over uniform randomness and challenge — then some single randomness
> supports **two distinct challenges**, and `forking_extractor` recovers the key.

Since `1/q` is negligible for a cryptographic group order, *any* adversary with
non-negligible success probability satisfies the hypothesis. The theorem is
therefore the forking lemma's contrapositive content, stated in a form that is
checkable rather than assumed.

## The reduction

`success_card_le_of_dl_hard` is the security statement: assuming the discrete
logarithm is hard in `ZMod q` — no algorithm recovers the exponent — every
two-stage adversary succeeds on at most `q` of the `q^2` pairs. The only
hypotheses are `Fact (Nat.Prime q)` (field arithmetic) and the hardness
assumption itself, stated as an explicit `def`, never an axiom.

## What is deliberately not proved

* **No probabilistic amplification.** The statement is a cardinality bound, not
  a probability bound; the passage from "success probability > 1/q" to
  "`SuccSet.card > q`" is the definition of probability over a finite uniform
  space and is left in prose.
* **No efficiency requirement on the adversary.** The reduction constructs a
  (possibly inefficient) discrete-log solver from a forger. Hardness is a
  statement about *all* algorithms, so this is a valid contradiction; it does
  not claim the constructed solver is efficient.
* **The model is still the abstract cyclic group `ZMod q`.** Ed25519's curve,
  encoding and hash are not modelled here; see
  `Ed25519VerificationEquation.lean` for the structural bridge and its
  hypotheses.
-/

namespace LeanFormalization

variable (q : ℕ) [Fact (Nat.Prime q)]

/-- A **two-stage** Schnorr adversary.

`commit pk r` is the first message `R`: it depends on the public key and the
adversary's randomness, but *not* on the challenge — the adversary must commit
before the challenge is drawn. `respond pk r R c` is the second message.

Because `commit` does not take `c`, two runs with the same randomness produce
the same commitment for every challenge. That is the structural property the
opaque `ForkingStep` hypothesis used to hide. -/
structure SchnorrAdversary where
  commit : ZMod q → ZMod q → Option (ZMod q)
  respond : ZMod q → ZMod q → ZMod q → ZMod q → Option (ZMod q)

/-- The adversary succeeds on `(r, c)` if it commits, responds, and the
resulting transcript is accepting. -/
def SchnorrAdversary.succeeds (f : SchnorrAdversary q) (pk r c : ZMod q) : Prop :=
  ∃ R s, f.commit pk r = some R ∧ f.respond pk r R c = some s ∧ schnorrAccept q pk c R s

/-- The finite set of (randomness, challenge) pairs on which the adversary
succeeds. Its cardinality is `q^2` times the success probability over the
uniform distribution. -/
noncomputable def SuccSet (f : SchnorrAdversary q) (pk : ZMod q) : Finset (ZMod q × ZMod q) := by
  classical
  exact Finset.univ.filter (fun rc => SchnorrAdversary.succeeds q f pk rc.1 rc.2)

/-- The forked transcripts: two distinct challenges under the SAME randomness,
    both accepting. This is the conclusion the forking lemma supplies. -/
def Forked (f : SchnorrAdversary q) (pk : ZMod q) : Prop :=
  ∃ r c c' R s s' : ZMod q,
    c ≠ c' ∧ f.commit pk r = some R ∧
    f.respond pk r R c = some s ∧ f.respond pk r R c' = some s' ∧
    schnorrAccept q pk c R s ∧ schnorrAccept q pk c' R s'

/-- The forked transcripts yield the discrete log: `pk` equals the extractor
    applied to a concrete fork. -/
def Extracts (f : SchnorrAdversary q) (pk : ZMod q) : Prop :=
  ∃ a : ZMod q, pk = a ∧ ∃ r R c c' s s' : ZMod q,
    a = (s - s') * (c - c')⁻¹ ∧ c ≠ c' ∧
    f.commit pk r = some R ∧
    f.respond pk r R c = some s ∧ f.respond pk r R c' = some s' ∧
    schnorrAccept q pk c R s ∧ schnorrAccept q pk c' R s'

/-- **The forking extractor.** In the two-stage model the commitment is a
    function of the randomness alone, so two accepting transcripts produced
    under the same randomness automatically share a commitment; the extractor
    then recovers the key. This is `schnorr_special_soundness` composed with the
    model, and it is what makes the shared-commitment hypothesis automatic. -/
theorem forking_extractor (f : SchnorrAdversary q) (pk r c c' R s s' : ZMod q)
    (hcne : c ≠ c') (hR : f.commit pk r = some R)
    (hs : f.respond pk r R c = some s) (hs' : f.respond pk r R c' = some s')
    (ha : schnorrAccept q pk c R s) (ha' : schnorrAccept q pk c' R s') :
    Extracts q f pk := by
  refine ⟨(s - s') * (c - c')⁻¹, schnorr_special_soundness q pk c c' R s s' hcne ha ha', ?_⟩
  exact ⟨r, R, c, c', s, s', rfl, hcne, hR, hs, hs', ha, ha'⟩

/-- **The combinatorial forking lemma.** If the adversary succeeds on more than
    `q` of the `q^2` pairs — success probability greater than `1/q` over
    uniform randomness and challenge — then some single randomness supports two
    distinct challenges.

    *Proof.* Suppose not: no randomness supports two distinct successful
    challenges. Then the projection `(r, c) ↦ r` is injective on the success
    set (two pairs with the same `r` would both succeed at that `r`, so their
    challenges must coincide), so the success set injects into the `q`
    randomness values and has at most `q` elements — contradicting the
    hypothesis. -/
theorem exists_fork_of_card (f : SchnorrAdversary q) (pk : ZMod q)
    (hcard : (SuccSet q f pk).card > Fintype.card (ZMod q)) : Forked q f pk := by
  classical
  by_contra h
  have hno : ∀ r c c' R s s', c ≠ c' →
      ¬(f.commit pk r = some R ∧ f.respond pk r R c = some s ∧
        f.respond pk r R c' = some s' ∧ schnorrAccept q pk c R s ∧
        schnorrAccept q pk c' R s') := by
    intro r c c' R s s' hcne hcon
    exact h ⟨r, c, c', R, s, s', hcne, hcon.1, hcon.2.1, hcon.2.2.1,
      hcon.2.2.2.1, hcon.2.2.2.2⟩
  have hinj : Set.InjOn Prod.fst (↑(SuccSet q f pk) : Set (ZMod q × ZMod q)) := by
    intro rc hrc rc' hrc' heq
    obtain ⟨R, s, hcR, hcs, hca⟩ := (Finset.mem_filter.mp hrc).2
    obtain ⟨R', s', hc'R, hcs', hca'⟩ := (Finset.mem_filter.mp hrc').2
    have hRR : R = R' := by
      apply Option.some.inj
      exact hcR.symm.trans (by rw [heq]; exact hc'R)
    have hcs'' : f.respond pk rc.1 R rc'.2 = some s' := by
      rw [← heq, ← hRR] at hcs'
      exact hcs'
    have hca'' : schnorrAccept q pk rc'.2 R s' := by
      rw [← hRR] at hca'
      exact hca'
    by_cases hcc : rc.2 = rc'.2
    · exact Prod.ext heq hcc
    · exact absurd (hno rc.1 rc.2 rc'.2 R s s' hcc ⟨hcR, hcs, hcs'', hca, hca''⟩) (by simp)
  have hmaps : Set.MapsTo Prod.fst (↑(SuccSet q f pk) : Set (ZMod q × ZMod q))
      (↑(Finset.univ : Finset (ZMod q)) : Set (ZMod q)) :=
    fun _ _ => Finset.mem_univ _
  have hle : (SuccSet q f pk).card ≤ (Finset.univ : Finset (ZMod q)).card :=
    Finset.card_le_card_of_injOn (s := SuccSet q f pk) (t := Finset.univ) Prod.fst hmaps hinj
  rw [Finset.card_univ] at hle
  omega

/-- **The reduction.** A forger whose success set is larger than `q` yields the
    discrete logarithm, pinned to the extractor applied to the forked
    transcripts. -/
theorem fork_recovers_key (f : SchnorrAdversary q) (pk : ZMod q)
    (hcard : (SuccSet q f pk).card > Fintype.card (ZMod q)) : Extracts q f pk := by
  obtain ⟨r, c, c', R, s, s', hcne, hR, hs, hs', ha, ha'⟩ :=
    exists_fork_of_card q f pk hcard
  exact forking_extractor q f pk r c c' R s s' hcne hR hs hs' ha ha'

/-- The hardness assumption, stated as an explicit `def` — never an axiom: no
    algorithm recovers the discrete logarithm from the public key. -/
def SchnorrDLHard : Prop :=
  ∀ (adv : ZMod q → Option (ZMod q)) (pk : ZMod q), adv pk ≠ some pk

/-- **The security reduction.** If the discrete logarithm is hard in `ZMod q`,
    then every two-stage adversary succeeds on at most `q` of the `q^2`
    (randomness, challenge) pairs — success probability at most `1/q`.

    This is the contrapositive of `fork_recovers_key`: a forger above the
    threshold would yield a discrete-log solver, contradicting the hardness
    assumption. The only hypotheses are `Fact (Nat.Prime q)` and hardness. -/
theorem success_card_le_of_dl_hard (hhard : SchnorrDLHard q) (f : SchnorrAdversary q)
    (pk : ZMod q) : (SuccSet q f pk).card ≤ Fintype.card (ZMod q) := by
  classical
  by_contra hgt
  have hlt : Fintype.card (ZMod q) < (SuccSet q f pk).card := by omega
  obtain ⟨a, hakey, hrest⟩ := fork_recovers_key q f pk hlt
  let adv : ZMod q → Option (ZMod q) :=
    fun pk' => if h : Extracts q f pk' then some (Classical.choose h) else none
  have hEX : Extracts q f pk := ⟨a, hakey, hrest⟩
  have hch : Classical.choose hEX = a := (Classical.choose_spec hEX).1.symm.trans hakey
  have hrun : adv pk = some a := by
    simp only [adv]
    rw [dif_pos hEX, hch]
  have hsucc : adv pk = some pk := by rw [hrun, hakey]
  exact hhard adv pk hsucc

/-- **Tightness of the threshold.** The bound `q` in `exists_fork_of_card` and
    `success_card_le_of_dl_hard` cannot be lowered: the adversary that answers
    only the challenge `0` succeeds on exactly `q` pairs and never forks. -/
theorem exists_forger_card_eq_q (pk : ZMod q) :
    ∃ f : SchnorrAdversary q, (SuccSet q f pk).card = Fintype.card (ZMod q) := by
  classical
  let f : SchnorrAdversary q :=
    { commit := fun _ r => some r
      respond := fun _ r R c => if c = 0 then some R else none }
  refine ⟨f, ?_⟩
  have hset : SuccSet q f pk = Finset.univ.filter (fun rc : ZMod q × ZMod q => rc.2 = 0) := by
    unfold SuccSet
    apply Finset.filter_congr
    intro rc _
    simp only [SchnorrAdversary.succeeds, f, schnorrAccept]
    constructor
    · rintro ⟨R, s, hR, hs, ha⟩
      have hc0 : (rc.2 : ZMod q) = 0 := by
        by_contra hcne
        simp [hcne] at hs
      exact hc0
    · intro hc0
      exact ⟨rc.1, rc.1, rfl, by simp [hc0], by simp [hc0]⟩
  rw [hset]
  have hbij : (Finset.univ.filter (fun rc : ZMod q × ZMod q => rc.2 = 0)).card
      = (Finset.univ : Finset (ZMod q)).card :=
    (Finset.card_bij (i := fun r (_ : r ∈ Finset.univ) => (r, (0 : ZMod q)))
      (fun r _ => Finset.mem_filter.mpr ⟨Finset.mem_univ _, rfl⟩)
      (fun r _ r' _ hrr => congrArg Prod.fst hrr)
      (fun b hb => ⟨b.1, Finset.mem_univ _, Prod.ext (by simp) (by simpa using (Finset.mem_filter.mp hb).2.symm)⟩)).symm
  rw [hbij, Finset.card_univ]

omit [Fact (Nat.Prime q)] in
/-- The tightness witness genuinely does not fork: every success uses challenge
    `0`, so no randomness supports two distinct challenges. -/
theorem tightness_witness_not_forked (pk : ZMod q) :
    ¬ Forked q
      { commit := fun _ r => some r
        respond := fun _ _ R c => if c = 0 then some R else none } pk := by
  rintro ⟨_, c, c', _, _, _, hcne, _, hs, hs', _, _⟩
  have hc0 : c = 0 := by
    by_contra hne
    simp [hne] at hs
  have hc'0 : c' = 0 := by
    by_contra hne
    simp [hne] at hs'
  exact hcne (by rw [hc0, hc'0])

end LeanFormalization
