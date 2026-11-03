import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- A minimal Ed25519-style signature scheme (placeholder).  The actual
    arithmetic is omitted – we only need a type for keys, signatures and
    a verification function.  The goal of this file is *not* to prove that
    Ed25519 satisfies UF-CMA in full detail; instead we show how an
    assumption about the signature's security can be turned into a
    `pqcUnforgeable` lemma that plugs straight into the rest of the
    formalization. -/
structure Ed25519Sig where
  pk : Nat
  sk : Nat
  deriving DecidableEq

/-- Placeholder verifier: accepts iff the signature equals the message.
    NOTE: this is deliberately insecure and exists only to fix the
    interface. It is NOT a real Ed25519 verification algorithm. -/
def ed25519Verify (sig : Nat) (msg : Nat) (_pk : Nat) : Bool :=
  sig = msg

/-- Turn an `Ed25519Sig` into a `PQCSig`.  The field names match those in
    `Common.lean`. -/
def Ed25519ToPQC (s : Ed25519Sig) : PQCSig where
  verify := fun m sig => ed25519Verify sig m s.pk
  forgeable := False -- placeholder; actual property is expressed below

/-- The placeholder verifier is trivially forgeable: an adversary can set
    the forgery signature equal to any fresh message and it verifies.
    This is a real, constructive proof (no axioms) and demonstrates why
    the UF-CMA assumption cannot be sound for this placeholder: the scheme
    must be replaced with a genuine Ed25519 verifier before any security
    claim can hold. -/
theorem placeholder_is_forgeable (s : Ed25519Sig) :
    ∃ adv : Adversary,
      ufCmaWins (Ed25519ToPQC s) (SignOracle.mk (fun _ => 0)) adv := by
  refine ⟨{ queries := [], forgeryMsg := 1, forgerySig := 1 }, ?_⟩
  constructor
  · simp [Ed25519ToPQC, ed25519Verify]
  · simp

/-- Conditional UF-CMA statement for Ed25519.  Security is taken as an
    explicit hypothesis (`h_secure`) rather than a global axiom, matching
    the style of `Theorem7`/`Theorem8`.  A full proof of `h_secure`
    requires (a) a genuine Ed25519 verifier in place of `ed25519Verify`
    and (b) a reduction from the discrete-log problem; neither is
    available in this repository today.  Until then, any caller that
    needs Ed25519 UF-CMA must supply `h_secure` (and is responsible for
    its justification). -/
theorem Ed25519_uf_cma (s : Ed25519Sig) (oracle : SignOracle)
    (h_secure : ∀ adv, ¬ ufCmaWins (Ed25519ToPQC s) oracle adv) :
    pqcUnforgeable (Ed25519ToPQC s) oracle := by
  intro adv
  exact h_secure adv

end LeanFormalization
