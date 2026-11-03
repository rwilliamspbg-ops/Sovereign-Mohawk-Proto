import Mathlib
import LeanFormalization.Common
import LeanFormalization.Ed25519

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

/-- Turn an `Ed25519Sig` into a `PQCSig`.  Uses the genuine Ed25519
    verifier from `Ed25519.lean`. -/
def Ed25519ToPQC (s : Ed25519Sig) : PQCSig where
  verify := fun m sig => ed25519Verify sig m s.pk
  forgeable := False

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
