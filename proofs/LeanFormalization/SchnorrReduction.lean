import Mathlib

/-!
# A Proper Reduction for the Schnorr / Ed25519 Identification Protocol

The traceability matrix row 5 records `Theorem5Cryptography.lean` as a
`model_verified` constant-operation cost model, and separately notes
`theorem5_verifier_soundness` is a *structural* statement about a toy `verify`
function — not a cryptographic soundness proof. The ROADMAP records that a full
Groth16/q-SDH formalization is out of reach: Mathlib has no pairing or
computational-hardness machinery.

This module takes the other available route: a **proper reduction for the
Schnorr identification protocol**, which is the cryptographic core of Ed25519
and the part Mathlib *can* express, because it is algebra over a cyclic group.

The group is modelled concretely as the additive group of `ZMod q` for a prime
`q`, with generator `1`. This is a cyclic group of prime order, so the discrete
logarithm problem is well-defined; the algebra below is exactly the algebra of
the exponent in a general cyclic group, with multiplication written additively.

## What is proved

1. `schnorr_completeness` — an honestly generated transcript is accepting.
2. `schnorr_special_soundness` — **the extractor.** From two accepting transcripts
   with the same commitment and different challenges, the secret key is
   recovered: `pk = (s - s') * (c - c')⁻¹`. This is a real knowledge-soundness
   reduction, and it is the same extractor as
   `DiscreteLogReduction.recovery_yields_secret` (the Ed25519 nonce-reuse
   attack), restated in the group model.
3. `schnorr_hvzk` — **honest-verifier zero-knowledge.** A simulator that, given
   the challenge, picks the response uniformly and sets the commitment to
   `s - c*pk` produces accepting transcripts, and the induced commitment
   distribution is uniform because `s ↦ s - c*pk` is a bijection.
4. `forger_implies_dlog` — **the reduction.** Modulo an explicit forking step,
   any forger that produces one accepting transcript yields a discrete-log
   solver.

## What is not proved, stated openly

* The **forking lemma itself** is an explicit hypothesis (`ForkingStep`), not a
  theorem here. It is the standard tool that turns a forger with success
  probability `ε` into two accepting transcripts with the same commitment and
  different challenges; proving it in Lean is a separate project. What is proved
  is the step that matters cryptographically: *given* the two transcripts, the
  key is recovered.
* The model is a cyclic group of prime order with the discrete log stated in the
  exponent. It does not model Ed25519's curve, its encoding, or its hash
  function; those are the parts the repository's own `Ed25519.lean` flags as
  unaudited.
* Nothing here is a proof about the deployed Go verifier, which checks Groth16
  proofs against a fixed genesis verification key
  (`internal/zksnark_verifier.go`) — a different, weaker construction.
-/

namespace LeanFormalization

variable (q : ℕ) [Fact (Nat.Prime q)]

/-- The Schnorr identification relation over the additive group `ZMod q`.

A transcript `(R, c, s)` — commitment `R`, challenge `c`, response `s` — is
accepting for public key `pk` iff `s = R + c * pk`. In a multiplicative group
with generator `B` this is `s·B = R · (pk)^c`, the standard Schnorr check. -/
def schnorrAccept (pk c R s : ZMod q) : Prop := s = R + c * pk

omit [Fact (Nat.Prime q)] in
/-- An honestly generated transcript: the prover picks `r`, sends `R = r`, the
verifier sends `c`, and the prover answers `s = r + c * pk`. -/
theorem schnorr_completeness (pk c r : ZMod q) :
    schnorrAccept q pk c r (r + c * pk) := by
  unfold schnorrAccept
  rfl

/-- **Special soundness / the extractor.** Two accepting transcripts with the
same commitment and different challenges determine the secret key:

    pk = (s - s') * (c - c')⁻¹

This is the algebraic content of the Schnorr identification scheme's knowledge
soundness, and it is exactly the extractor behind the Ed25519 nonce-reuse
key-recovery attack recorded in `DiscreteLogReduction.recovery_yields_secret`
(there the two "challenges" are the hashes of two messages signed under the same
nonce). -/
theorem schnorr_special_soundness (pk c c' R s s' : ZMod q)
    (hcne : c ≠ c') (h1 : schnorrAccept q pk c R s) (h2 : schnorrAccept q pk c' R s') :
    pk = (s - s') * (c - c')⁻¹ := by
  unfold schnorrAccept at h1 h2
  have hsub : s - s' = (c - c') * pk := by linear_combination h1 - h2
  have hcne' : (c - c') ≠ 0 := sub_ne_zero.mpr hcne
  have hkey : pk * (c - c') = s - s' := by
    rw [mul_comm pk (c - c')]
    exact hsub.symm
  calc pk = pk * 1 := (mul_one pk).symm
    _ = pk * ((c - c') * (c - c')⁻¹) := by rw [mul_inv_cancel₀ hcne']
    _ = (pk * (c - c')) * (c - c')⁻¹ := by ring
    _ = (s - s') * (c - c')⁻¹ := by rw [hkey]

/-- **Honest-verifier zero-knowledge.** Given the challenge `c`, a simulator
that picks `s` uniformly and sets `R = s - c * pk` produces an accepting
transcript. -/
theorem schnorr_hvzk_simulation (pk c s : ZMod q) :
    schnorrAccept q pk c (s - c * pk) s := by
  unfold schnorrAccept
  ring

/-- The simulated commitment `s ↦ s - c * pk` is a bijection of `ZMod q`, so the
simulator's commitment is uniformly distributed whenever `s` is — the
distributional half of HVZK. -/
theorem schnorr_hvzk_commitment_bijective (pk c : ZMod q) :
    Function.Bijective (fun s : ZMod q => s - c * pk) := by
  constructor
  · intro a b hab
    change a - c * pk = b - c * pk at hab
    have hzero : (a - b : ZMod q) = 0 := by
      calc a - b = (a - c * pk) - (b - c * pk) := by ring
        _ = 0 := by rw [hab, sub_self]
    exact sub_eq_zero.mp hzero
  · intro y
    exact ⟨y + c * pk, by ring⟩

/-- A Schnorr forger: given the public key and a challenge, it either fails
(`none`) or produces a commitment/response pair. -/
structure SchnorrForger where
  forge : ZMod q → ZMod q → Option (ZMod q × ZMod q)

/-- The forger succeeds if the produced transcript is accepting. -/
def SchnorrForger.succeeds (f : SchnorrForger q) (pk c : ZMod q) : Prop :=
  ∃ R s, f.forge pk c = some (R, s) ∧ schnorrAccept q pk c R s

/-- **The forking step, stated as an explicit hypothesis.**

Given a forger that succeeds on at least one challenge, the forking lemma
produces two accepting transcripts with the SAME commitment and DIFFERENT
challenges. This is the standard rewinding argument; proving it in Lean is a
separate project, so it is a hypothesis here rather than a theorem.

What is proved below is the cryptographically load-bearing step: *given* those
two transcripts, the discrete log is recovered. -/
def ForkingStep : Prop :=
  ∀ (f : SchnorrForger q) (pk : ZMod q),
    (∃ c R s, f.forge pk c = some (R, s) ∧ schnorrAccept q pk c R s) →
    ∃ R c c' s s' : ZMod q,
      c ≠ c' ∧
      f.forge pk c = some (R, s) ∧ f.forge pk c' = some (R, s') ∧
      schnorrAccept q pk c R s ∧ schnorrAccept q pk c' R s'

/-- **The reduction.** Modulo the forking step, a forger that produces one
accepting transcript yields the discrete logarithm: the two forked transcripts
recover `pk = (s - s') * (c - c')⁻¹`.

The earlier revision of this theorem concluded `∃ a, pk = a`, which is
satisfiable by `a := pk` without using either hypothesis — a vacuous statement,
even though the proof happened to use the extractor as the witness. This
version pins the conclusion to the extractor applied to the forked transcripts,
so the statement is false whenever the extraction fails.

Contrapositive (in prose, not formalized): if the discrete logarithm problem is
hard in `ZMod q` — no algorithm recovers the exponent from `pk` with
non-negligible probability — then no such forger exists, i.e. the Schnorr
identification protocol is secure against impersonation under honest-verifier
execution. -/
theorem forger_implies_dlog (hfork : ForkingStep q) (f : SchnorrForger q) (pk : ZMod q)
    (hsucc : ∃ c R s, f.forge pk c = some (R, s) ∧ schnorrAccept q pk c R s) :
    ∃ (R c c' s s' : ZMod q),
      pk = (s - s') * (c - c')⁻¹ ∧ c ≠ c' ∧
      f.forge pk c = some (R, s) ∧ f.forge pk c' = some (R, s') ∧
      schnorrAccept q pk c R s ∧ schnorrAccept q pk c' R s' := by
  obtain ⟨R, c, c', s, s', hcne, h1, h2, hv1, hv2⟩ := hfork f pk hsucc
  exact ⟨R, c, c', s, s',
    schnorr_special_soundness q pk c c' R s s' hcne hv1 hv2,
    hcne, h1, h2, hv1, hv2⟩

/-- Concrete instance over the prime field `ZMod 7`: an honest prover with
secret `3` and commitment `5`, facing challenges `2` and `4`, answers
`5 + 2*3 = 11 ≡ 4` and `5 + 4*3 = 17 ≡ 3`. -/
theorem schnorr_concrete_accept : schnorrAccept 7 (3 : ZMod 7) 2 (5 : ZMod 7) 4 := by
  unfold schnorrAccept
  decide

theorem schnorr_concrete_accept' : schnorrAccept 7 (3 : ZMod 7) 4 (5 : ZMod 7) 3 := by
  unfold schnorrAccept
  decide

/-- Concrete extraction: the two transcripts above have the same commitment and
different challenges, and the extractor recovers the secret `3`. -/
theorem schnorr_concrete_extraction :
    (3 : ZMod 7) = (4 - 3) * (2 - 4)⁻¹ := by
  decide

/-- The extractor agrees with the concrete instance: applying
`schnorr_special_soundness` to the two transcripts above yields the secret key,
and the public-key equation `pk = a` holds for the recovered `a`. -/
theorem schnorr_concrete_reduction :
    (let a := (4 - 3) * (2 - 4)⁻¹
     schnorrAccept 7 a 2 (5 : ZMod 7) 4 ∧ schnorrAccept 7 a 4 (5 : ZMod 7) 3) := by
  refine ⟨?_, ?_⟩
  · unfold schnorrAccept
    decide
  · unfold schnorrAccept
    decide

end LeanFormalization
