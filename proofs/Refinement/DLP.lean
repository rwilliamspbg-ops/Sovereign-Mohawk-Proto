import Mathlib
import LeanFormalization.Ed25519
import LeanFormalization.Ed25519VerificationEquation

/-!
# DLP Refinement: Lean Spec ↔ Go Implementation (Ed25519)

This module relates the runtime's Ed25519 acceptance condition to the
**verification equation** `S·B = R + h·A`, and through it to the proved
nonce-reuse key-recovery extractor (`Ed25519VerificationEquation.lean`).

## Removed as a vacuous stub (2026-11-20)

The previous revision of this module was a placeholder, and its own comments
said so:

* `dlpHard (_g) (_gx) : Prop := True` — a hardness assumption that assumed
  nothing ("placeholder hardness").
* `dlpSpecVerify stmt sig := stmt.pk ≠ 0 ∧ sig.sigBytes ≠ []` — a structural
  guard, not Ed25519 verification.
* `dlpImplVerify pk _ msg sig := pk ≠ 0 && !sig.isEmpty` — the **same** guard
  re-implemented, so `dlp_impl_refines_spec` was a tautology and
  `dlp_impl_complete` was near-tautological.
* `dlpImplSign sk _ := if sk = 0 then [] else [1]` — a toy signing function.

None of that is load-bearing anywhere (only `scripts/check_refinement.py`
referenced the four names), so the module is rebuilt rather than patched.

## What is proved here

* `dlp_impl_refines_spec` — the runtime's coordinate check accepts ⇒ the
  verification equation holds. This is now a real statement: the impl is
  `ed25519VerifyCore`'s actual comparison (`S·B` and `R + h·A` agree on both
  affine coordinates, neither at infinity) and the spec is
  `Ed25519VerificationEquation`.
* `dlp_impl_complete` — the converse, **conditional on non-infinity**. The
  condition is load-bearing: `dlp_impl_infinity_gap` exhibits a statement and
  witness satisfying the spec (both sides the point at infinity) that the
  runtime rejects.
* `dlp_nonce_reuse_recovers` — two accepting witnesses sharing the nonce point
  and differing in the challenge recover the secret key, by way of
  `ed25519_two_equations_recover`.

## What is deliberately not claimed

The byte-level decode (`decodePoint`, `sha512`, the 64-byte signature layout)
is not refined here; `dlpImplVerify` is the *comparison* `ed25519VerifyCore`
performs once decoding has succeeded. Full UF-CMA is not claimed either — the
extractor needs nonce reuse, which an honest signer never produces (see
`docs/EXTERNAL_AUDIT_SCOPE.md` §3.2).
-/

namespace Refinement

open LeanFormalization

/-- Spec statement: the public-key point, the nonce point, and the message
    bytes. --/
structure DLPSpec where
  keyPoint : AffinePoint
  noncePoint : AffinePoint
  message : List UInt8

/-- Spec witness: the secret scalar, the response scalar `S`, and the
    challenge `h`. --/
structure DLPWitness where
  sk : Nat
  response : Nat
  challenge : Nat

/-- **Spec (Lean): the Ed25519 verification equation.** `S·B = R + h·A` for the
    statement's key point `A` and nonce point `R`. This is
    `Ed25519VerificationEquation`, not a structural guard. -/
def dlpSpecVerify (spec : DLPSpec) (w : DLPWitness) : Prop :=
  Ed25519VerificationEquation affineBase spec.keyPoint spec.noncePoint
    w.response w.challenge

/-- **Impl (Go): the runtime's acceptance condition.** Exactly the comparison
    `ed25519VerifyCore` performs after decoding: `S·B` and `R + h·A` must agree
    on both affine coordinates and neither may be the point at infinity. -/
def dlpImplVerify (spec : DLPSpec) (w : DLPWitness) : Bool :=
  (affineScalarMulImpl w.response affineBase).x ==
    (affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)).x &&
  (affineScalarMulImpl w.response affineBase).y ==
    (affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)).y &&
  !(affineScalarMulImpl w.response affineBase).inf &&
  !(affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)).inf

/-- Two affine points with the same coordinates (including the infinity flag)
    are equal. -/
theorem affinePoint_eq_of_coords {P Q : AffinePoint}
    (hx : P.x = Q.x) (hy : P.y = Q.y) (hinf : P.inf = Q.inf) : P = Q := by
  cases P
  cases Q
  rw [AffinePoint.mk.injEq]
  exact ⟨hx, hy, hinf⟩

/-- **Refinement (soundness).** The runtime's coordinate check accepts exactly
    when the verification equation holds: agreeing `x`, agreeing `y` and both
    points non-infinite make the two `AffinePoint`s equal. -/
theorem dlp_impl_refines_spec (spec : DLPSpec) (w : DLPWitness)
    (h : dlpImplVerify spec w = true) : dlpSpecVerify spec w := by
  unfold dlpSpecVerify dlpImplVerify Ed25519VerificationEquation at *
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h
  simp only [beq_iff_eq] at h
  have hinf1 : (affineScalarMulImpl w.response affineBase).inf = false := by
    simpa using h.1.2
  have hinf2 : (affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)).inf
      = false := by
    simpa using h.2
  exact affinePoint_eq_of_coords h.1.1.1 h.1.1.2 (hinf1.trans hinf2.symm)

/-- **Completeness.** If the verification equation holds and the left side is
    not the point at infinity, the runtime accepts. The non-infinity hypothesis
    is load-bearing — see `dlp_impl_infinity_gap`. -/
theorem dlp_impl_complete (spec : DLPSpec) (w : DLPWitness)
    (h : dlpSpecVerify spec w)
    (hinf : (affineScalarMulImpl w.response affineBase).inf = false) :
    dlpImplVerify spec w = true := by
  unfold dlpSpecVerify dlpImplVerify Ed25519VerificationEquation at *
  have hinf' : (affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)).inf
      = false := by
    rw [← h]
    exact hinf
  rw [h, hinf']
  simp

/-- **Negative control: the non-infinity condition is load-bearing.** A
    statement and witness whose two sides are both the point at infinity
    satisfy the spec (the two points are equal) but are rejected by the
    runtime, because `ed25519VerifyCore` explicitly requires
    `!SB.inf && !RhA.inf`. -/
theorem dlp_impl_infinity_gap (spec : DLPSpec) (w : DLPWitness)
    (hSB : affineScalarMulImpl w.response affineBase = affineIdentity)
    (hRhA : affineAdd spec.noncePoint (affineScalarMulImpl w.challenge spec.keyPoint)
      = affineIdentity) :
    dlpSpecVerify spec w ∧ dlpImplVerify spec w = false := by
  constructor
  · unfold dlpSpecVerify Ed25519VerificationEquation
    rw [hSB, hRhA]
  · unfold dlpImplVerify
    rw [hSB, hRhA]
    simp [affineIdentity]

/-- **The nonce-reuse bridge.** Two accepting witnesses that share the nonce
    point and differ in the challenge recover the secret key — the runtime's
    acceptance condition feeds the proved extractor. -/
theorem dlp_nonce_reuse_recovers (hp : Fact (Nat.Prime dlL))
    (hlaws : Ed25519GroupLaws affineBase)
    (spec : DLPSpec) (r : Nat) (w w' : DLPWitness)
    (hkey : spec.keyPoint = affineScalarMulImpl w.sk affineBase)
    (hnonce : spec.noncePoint = affineScalarMulImpl r affineBase)
    (h1 : dlpSpecVerify spec w) (h2 : dlpSpecVerify spec w')
    (hdiff : ¬ Nat.ModEq dlL w.challenge w'.challenge) :
    (recoverSecret hp w.response w'.response w.challenge w'.challenge) % dlL
      = w.sk % dlL :=
  ed25519_two_equations_recover hp hlaws w.sk r spec.keyPoint spec.noncePoint
    w.challenge w'.challenge w.response w'.response hkey hnonce h1 h2 hdiff

end Refinement
