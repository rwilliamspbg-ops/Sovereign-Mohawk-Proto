import Mathlib
import LeanFormalization.Theorem7PQCMigrationContinuity

namespace LeanFormalization

/-- A migration is hijack-safe when PQC authorization is required at cutover. -/
def hijackSafe (auth : MigrationAuth) : Prop :=
  auth.pqcSigned = true

/-- Non-hijack theorem: post-epoch acceptance implies hijack safety. -/
theorem theorem8_post_epoch_non_hijack (auth : MigrationAuth)
    (h_post : postEpochAccepts auth) :
    hijackSafe auth := by
  exact h_post.2

/-- Negative form: without PQC signature, hijack safety cannot hold. -/
theorem theorem8_no_pqc_not_safe (auth : MigrationAuth)
    (h_no_pqc : auth.pqcSigned = false) :
    ¬ hijackSafe auth := by
  intro hsafe
  unfold hijackSafe at hsafe
  rw [h_no_pqc] at hsafe
  decide

end LeanFormalization
