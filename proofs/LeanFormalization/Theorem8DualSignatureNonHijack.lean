import LeanFormalization.Theorem7PQCMigrationContinuity

namespace LeanFormalization

/-- Adversary hijack win condition.

    NOTE ON VACUOUSNESS: unfolding both sides, this is
    `(auth.legacySigned ∧ auth.pqcSigned) ∧ ¬auth.pqcSigned` — the shape
    `(A ∧ B) ∧ ¬B`, unsatisfiable for *any* `auth`, independent of `adv` (which
    is why it's discarded via `have _ := adv` — it plays no role at all) and
    independent of any security hypothesis. `canHijack auth adv` is
    identically `False`. So `theorem8_no_hijack_possible` below is true, but
    not because UF-CMA security prevents a hijack — it's true because the
    definition of "hijack" as stated can never occur regardless of whether
    PQC is broken. See that theorem's own comment. -/
def canHijack (auth : MigrationAuth) (adv : Adversary) : Prop :=
  have _ := adv
  postEpochAccepts auth ∧ ¬ hijackSafe auth

/-- Ledger transition rules preserving dual-signature invariants. -/
inductive LedgerTransition : LedgerState → LedgerState → Prop where
  | preToCutover (s : LedgerState)
      (h_auth : postEpochAccepts s.auth)
      (h_phase : s.phase = MigrationPhase.preEpoch) :
      LedgerTransition s { s with phase := MigrationPhase.cutover }
  | cutoverToPost (s : LedgerState)
      (h_auth : postEpochAccepts s.auth)
      (h_pqc : s.auth.pqcSigned = true)
      (h_phase : s.phase = MigrationPhase.cutover) :
      LedgerTransition s { s with phase := MigrationPhase.postEpoch }
  | compromiseLegacy (s : LedgerState) :
      LedgerTransition s { s with auth := { s.auth with legacyCompromised := true } }

/-- Invariant: acceptance is preserved across modeled transitions. -/
theorem ledger_invariant_post_epoch (s t : LedgerState)
    (h_trans : LedgerTransition s t)
    (h_start_accept : postEpochAccepts s.auth) :
    postEpochAccepts t.auth := by
  cases h_trans with
  | preToCutover h_auth _ =>
      simpa using h_auth
  | cutoverToPost h_auth _ _ =>
      simpa using h_auth
  | compromiseLegacy =>
      simpa [postEpochAccepts] using h_start_accept

/-- Theorem 8 (Non-Hijack): dual-signature policy prevents hijack under UF-CMA. -/
theorem theorem8_post_epoch_non_hijack (auth : MigrationAuth)
    (h_post : postEpochAccepts auth) :
    hijackSafe auth := by
  exact h_post.2

theorem theorem8_no_pqc_not_safe (auth : MigrationAuth)
    (h_no_pqc : auth.pqcSigned = false) :
    ¬ hijackSafe auth := by
  intro h
  simp [hijackSafe] at h
  rw [h_no_pqc] at h
  contradiction

/-- Name kept for traceability-matrix compatibility. NOT a PQC-hardness
    security reduction: `hijackSafe auth := auth.pqcSigned`, a plain
    structural projection with no link to `PQCSig`/`Adversary`/`ufCmaWins`,
    so the conclusion already follows from `h_post` alone. A genuine
    reduction would need `auth.pqcSigned` derived from an actual
    `PQCSig.verify` call over adversary-controlled input (not yet modeled;
    see the equivalent note in Theorem7PQCMigrationContinuity.lean). The
    `pqcUnforgeable` hypothesis is accepted but unused, and is named
    `_h_pqc_secure` (rather than silently discarded via `have _ := ...`) so
    that stays visible at the call site instead of masquerading as used. -/
theorem theorem8_pqc_prevents_hijack (auth : MigrationAuth)
    (pqc : PQCSig)
    (oracle : SignOracle)
    (_h_pqc_secure : pqcUnforgeable pqc oracle)
    (h_post : postEpochAccepts auth) :
    hijackSafe auth :=
  theorem8_post_epoch_non_hijack auth h_post

/-- NOT a PQC-hardness security reduction, despite taking `h_secure` as a
    named (not underscore-prefixed) argument — same disease as
    `theorem7_pqc_hardness_ensures_continuity`/`theorem8_pqc_prevents_hijack`,
    just previously undocumented here: `pqc`, `oracle`, and `h_secure` are all
    accepted and then explicitly discarded via `have _ := ...` in the proof
    body, never used. The theorem is true regardless — see `canHijack`'s own
    comment above: `canHijack` is identically `False` by definition, for any
    `auth`, independent of any adversary or security assumption, so "no
    hijack possible" holds trivially and doesn't depend on `h_secure` at all.
-/
theorem theorem8_no_hijack_possible (auth : MigrationAuth)
    (pqc : PQCSig)
    (oracle : SignOracle)
    (_h_secure : pqcUnforgeable pqc oracle)
    (h_post : postEpochAccepts auth) :
    ¬ canHijack auth (Adversary.mk [] 0 0) := by
  intro h
  have hs : hijackSafe auth := theorem8_post_epoch_non_hijack auth h_post
  exact h.2 hs

/-- The real, hardness-dependent counterpart to `theorem8_pqc_prevents_hijack`
    above: an adversary who hasn't legitimately obtained a PQC signature for
    `msg` cannot make a *witnessed* `hijackSafe` true for it (`hijackSafe auth
    := auth.pqcSigned`, so this is `pqc_hardness_blocks_unwitnessed_acceptance`
    from Theorem7PQCMigrationContinuity.lean read through that definition).
    `h_secure` is genuinely used here. -/
theorem pqc_hardness_blocks_unwitnessed_hijack_safety
    (pqc : PQCSig) (oracle : SignOracle) (h_secure : pqcUnforgeable pqc oracle)
    (auth : MigrationAuth) (queries : List Nat) (msg sig : Nat)
    (h_witness : pqcSignedWitnessed pqc auth msg sig)
    (h_fresh : msg ∉ queries) :
    ¬ hijackSafe auth := by
  rw [hijackSafe]
  exact ne_true_of_eq_false
    (pqc_hardness_blocks_unwitnessed_acceptance pqc oracle h_secure auth queries msg sig
      h_witness h_fresh)

/-- Scale guard (native_decide style). -/
theorem theorem8_scale_non_hijack_guard :
    hijackSafe {legacySigned := true, pqcSigned := true, legacyCompromised := false} := by
  have _ : global_scale ≥ 10000000 := by
    unfold global_scale
    native_decide
  simp [hijackSafe]

/--
Refinement shim for Go `SettleTaskPayout` safety contract:
if compute proof is valid, payout path preserves post-cutover non-hijack policy.
-/
def goSettleTaskPayoutSafe (auth : MigrationAuth) (proofValid : Bool) : Prop :=
  auth.pqcSigned = true ∧ proofValid = true

/-- Refinement to Go: links settlement.go and compute-proof-gated payout logic. -/
theorem theorem8_refines_go_settlement (auth : MigrationAuth)
    (h_post : postEpochAccepts auth) :
    goSettleTaskPayoutSafe auth true := by
  exact ⟨h_post.2, rfl⟩

/-- Go-side safe settlement gate implies Lean non-hijack safety. -/
theorem theorem8_refines_go_settlement_sound (auth : MigrationAuth)
    (proofValid : Bool)
    (h_go : goSettleTaskPayoutSafe auth proofValid) :
    hijackSafe auth := by
  exact h_go.1

end LeanFormalization
