import Mathlib
import LeanFormalization.Common
import LeanFormalization.Ed25519
import LeanFormalization.TheoremUF_CMA_Ed25519

namespace LeanFormalization

/-- Under an explicit UF-CMA hypothesis, no adversary wins. -/
theorem Ed25519_uf_cma_no_win (s : Ed25519Sig) (oracle : SignOracle)
    (h_secure : ∀ adv, ¬ ufCmaWins (Ed25519ToPQC s) oracle adv) :
    ∀ adv, ¬ ufCmaWins (Ed25519ToPQC s) oracle adv :=
  h_secure

end LeanFormalization
