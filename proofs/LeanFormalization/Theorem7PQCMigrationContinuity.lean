import Mathlib

namespace LeanFormalization

inductive MigrationPhase where
  | preEpoch
  | cutover
  | postEpoch

structure MigrationAuth where
  legacySigned : Bool
  pqcSigned : Bool
  legacyCompromised : Bool

/-- During post-epoch migration, only dual signatures are accepted. -/
def postEpochAccepts (auth : MigrationAuth) : Prop :=
  auth.legacySigned = true ∧ auth.pqcSigned = true

/-- If both signatures are present, post-epoch acceptance holds. -/
theorem theorem7_dual_signature_continuity (auth : MigrationAuth)
    (h_legacy : auth.legacySigned = true)
    (h_pqc : auth.pqcSigned = true) :
    postEpochAccepts auth := by
  exact ⟨h_legacy, h_pqc⟩

/-- Legacy-key compromise alone is insufficient for post-epoch acceptance. -/
theorem theorem7_legacy_compromise_insufficient (auth : MigrationAuth)
    (h_comp : auth.legacyCompromised = true)
    (h_post : postEpochAccepts auth) :
    auth.pqcSigned = true := by
  exact h_post.2

end LeanFormalization
