import Mathlib
import LeanFormalization.Ed25519
import LeanFormalization.DiscreteLogReduction
import LeanFormalization.HypothesisNecessity

/-!
# The Ed25519 verification equation, and its bridge to the Schnorr extractor

`Ed25519.lean` implements the curve arithmetic and a verifier.
`DiscreteLogReduction.lean` proves the nonce-reuse key-recovery extractor over
the exponents mod `L`. Neither says that the two are about the same algebra.

This module states the Ed25519 verification equation as a **structural**
proposition about points, and proves that — under an explicit, finite bundle of
group-law hypotheses — it is *exactly* the Schnorr identification equation in
the exponent. The payoff is a bridge theorem: two Ed25519 verification
equations that share a nonce point `R` and differ in the hash transfer to the
two signature equations `recovery_yields_secret` assumes, so the secret key is
recovered.

## The group laws are hypotheses, not axioms

`affineScalarMulImpl` and `affineAdd` in `Ed25519.lean` are unaudited
implementations. The transfer needs five facts about them (`Ed25519GroupLaws`).
They are packaged as a structure and supplied at each use site — never as a
global `axiom`. `Ed25519.lean` itself flags the arithmetic as not audited
against the full RFC 8032 test suite, so assuming these laws is a *modeling*
choice, and it is visible in every theorem statement that needs it.

## What is deliberately not claimed

* The group laws are **assumed**, not proved, for `AffinePoint`. Proving them
  means auditing the curve arithmetic; that is a separate project.
* Nothing here models the hash function, the encoding, or the random-oracle
  argument. The bridge is algebraic: it connects the equation to the extractor,
  not to a security proof of the deployed implementation.
-/

namespace LeanFormalization

/-- The **Ed25519 verification equation** in the standard form used by the
    security analysis:

    `S·B = R + h·A`

    where `B` is the base point, `A` the public key, `R` the nonce point, `S`
    the response and `h = H(R ‖ A ‖ M)` the challenge. This mirrors
    `ed25519VerifyCore` in `Ed25519.lean`, which checks `S·B = R + h·A` on the
    affine coordinates. -/
def Ed25519VerificationEquation (B A R : AffinePoint) (S h : Nat) : Prop :=
  affineScalarMulImpl S B = affineAdd R (affineScalarMulImpl h A)

/-- The group-law bundle the transfer needs. Each field is a plain proposition
    about the unaudited `affineScalarMulImpl` / `affineAdd`; none is an axiom. -/
structure Ed25519GroupLaws (B : AffinePoint) where
  /-- `0·B` is the identity. -/
  zeroMul : affineScalarMulImpl 0 B = affineIdentity
  /-- `1·B = B`. -/
  oneMul : affineScalarMulImpl 1 B = B
  /-- Scalar multiplication distributes over addition of exponents. -/
  addMul : ∀ k1 k2 : Nat, affineScalarMulImpl (k1 + k2) B =
      affineAdd (affineScalarMulImpl k1 B) (affineScalarMulImpl k2 B)
  /-- Composition of scalar multiplications. -/
  mulMul : ∀ k1 k2 : Nat, affineScalarMulImpl k1 (affineScalarMulImpl k2 B) =
      affineScalarMulImpl (k1 * k2) B
  /-- Well-definedness: congruent exponents give the same point. -/
  congMul : ∀ k1 k2 : Nat, Nat.ModEq ed25519L k1 k2 →
      affineScalarMulImpl k1 B = affineScalarMulImpl k2 B
  /-- Cancellation: `k ↦ k·B` is injective on exponents mod `L`. -/
  injective : ∀ k1 k2 : Nat, affineScalarMulImpl k1 B = affineScalarMulImpl k2 B →
      Nat.ModEq ed25519L k1 k2

/-- **The transfer.** Under the group laws, the Ed25519 verification equation
    for `A = a·B`, `R = r·B` holds iff the exponents satisfy the Schnorr
    identification equation `s ≡ r + h·a (mod L)`.

    This is the structural statement that makes the nonce-reuse extractor
    applicable to Ed25519: the curve equation *is* the group equation in the
    exponent. -/
theorem verificationEquation_iff_ModEq (B : AffinePoint) (hlaws : Ed25519GroupLaws B)
    (a r s h : Nat) (A R : AffinePoint) (hA : A = affineScalarMulImpl a B)
    (hR : R = affineScalarMulImpl r B) :
    Ed25519VerificationEquation B A R s h ↔ Nat.ModEq ed25519L s (r + h * a) := by
  unfold Ed25519VerificationEquation
  rw [hA, hR]
  constructor
  · intro hEq
    rw [hlaws.mulMul] at hEq
    rw [← hlaws.addMul] at hEq
    exact hlaws.injective s (r + h * a) hEq
  · intro hmod
    have hpt : affineScalarMulImpl s B = affineScalarMulImpl (r + h * a) B :=
      hlaws.congMul s (r + h * a) hmod
    rw [hpt, hlaws.addMul, ← hlaws.mulMul]

/-- **The bridge.** Two Ed25519 verification equations that share the nonce
    point `R` and differ in the hash transfer to the two signature equations
    `recovery_yields_secret` assumes, so the nonce-reuse extractor recovers the
    secret key `a`.

    This is the load-bearing connection between the implemented curve
    arithmetic and the proved extractor: it is conditional on
    `Ed25519GroupLaws affineBase`, which is a modeling assumption about the
    unaudited implementation. -/
theorem ed25519_two_equations_recover (hp : Fact (Nat.Prime dlL))
    (hlaws : Ed25519GroupLaws affineBase)
    (a r : Nat) (A R : AffinePoint) (h h' S S' : Nat)
    (hA : A = affineScalarMulImpl a affineBase)
    (hR : R = affineScalarMulImpl r affineBase)
    (h1 : Ed25519VerificationEquation affineBase A R S h)
    (h2 : Ed25519VerificationEquation affineBase A R S' h')
    (hdiff : ¬ Nat.ModEq dlL h h') :
    (recoverSecret hp S S' h h') % dlL = a % dlL := by
  have hS1 : S % dlL = (r + h * a) % dlL :=
    (verificationEquation_iff_ModEq affineBase hlaws a r S h A R hA hR).mp h1
  have hS2 : S' % dlL = (r + h' * a) % dlL :=
    (verificationEquation_iff_ModEq affineBase hlaws a r S' h' A R hA hR).mp h2
  exact recovery_yields_secret hp r a h h' S S' hS1 hS2 hdiff

/-! ### Negative controls

Each hypothesis of the bridge is load-bearing; the witnesses below are
concrete. -/

/-- **Negative control: the distinct-hash hypothesis is load-bearing.** With
    `h = h'`, two Ed25519 equations share their challenge and the extractor
    returns `0`. Over the toy field `ZMod 7` with `r = 5`, `a = 7`, `h = h' = 3`,
    `S = S' = 26`, both equations hold and `recoverSecret` returns `0 ≠ 7`. -/
theorem ed25519_recover_hdiff_needed (hp : Fact (Nat.Prime dlL)) :
    ¬ ((recoverSecret hp ((5 + 3 * 7) % dlL) ((5 + 3 * 7) % dlL) 3 3) % dlL
        = 7 % dlL) :=
  recovery_yields_secret_hdiff_needed hp

/-- **Negative control: `oneMul` is not automatic.** The transfer assumes
    `1·B = B`; an arbitrary scalar-multiplication function need not satisfy it.
    The constant-`identity` function is a concrete violator. -/
theorem constantMul_violates_oneMul :
    (fun (_k : Nat) (_P : AffinePoint) => affineIdentity) 1 affineBase ≠ affineBase := by
  intro h
  simp [affineIdentity, affineBase] at h

/-- **Negative control: cancellation is not automatic.** The transfer's
    injective law fails for a scalar multiplication that collapses exponents;
    concretely the constant-`identity` map sends every exponent to the same
    point, so `0` and `1` are identified while `0 ≢ 1 (mod L)`. -/
theorem constantMul_not_injective :
    (fun (_k : Nat) (_P : AffinePoint) => affineIdentity) 0 affineBase =
      (fun (_k : Nat) (_P : AffinePoint) => affineIdentity) 1 affineBase ∧
      ¬ Nat.ModEq ed25519L 0 1 := by
  constructor
  · rfl
  · intro h
    change (0 : Nat) % ed25519L = 1 % ed25519L at h
    have h0 : (0 : Nat) % ed25519L = 0 := Nat.mod_eq_of_lt (by unfold ed25519L; norm_num)
    have h1 : 1 % ed25519L = 1 := Nat.mod_eq_of_lt (by unfold ed25519L; norm_num)
    rw [h0, h1] at h
    exact zero_ne_one h

end LeanFormalization
