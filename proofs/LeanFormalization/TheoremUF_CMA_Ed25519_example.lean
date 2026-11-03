import Mathlib
import LeanFormalization.Common
import LeanFormalization.TheoremUF_CMA_Ed25519

namespace LeanFormalization

/-- The placeholder scheme is forgeable: there exists a winning adversary. -/
theorem Ed25519_placeholder_forgeable (s : Ed25519Sig) :
    ∃ adv, ufCmaWins (Ed25519ToPQC s) (SignOracle.mk (fun _ => 0)) adv :=
  placeholder_is_forgeable s

/-- Under an explicit UF-CMA hypothesis, no adversary wins. -/
theorem Ed25519_uf_cma_no_win (s : Ed25519Sig) (oracle : SignOracle)
    (h_secure : ∀ adv, ¬ ufCmaWins (Ed25519ToPQC s) oracle adv) :
    ∀ adv, ¬ ufCmaWins (Ed25519ToPQC s) oracle adv :=
  h_secure

end LeanFormalization
