import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/-- Theorem 7 (Continuity): dual signatures preserve acceptance after legacy compromise. -/
theorem theorem7_dual_signature_continuity (auth : MigrationAuth)
    (h_legacy : auth.legacySigned = true)
    (h_pqc : auth.pqcSigned = true) :
    postEpochAccepts auth := by
  exact ⟨h_legacy, h_pqc⟩

-- The two theorems below previously took a `legacyCompromised`/
-- `pqcUnforgeable` hypothesis and discarded it via `have _ := h`, which
-- silences Lean's unused-variable linter without the hypothesis doing any
-- work in the proof: `postEpochAccepts auth := auth.legacySigned ∧
-- auth.pqcSigned` is a plain structural conjunction with no link to
-- `legacyCompromised`, `PQCSig`, or the `Adversary`/`ufCmaWins` model in
-- Common.lean, so `auth.pqcSigned = true` already follows from `h_post`
-- alone regardless of whether legacy is compromised or PQC is unforgeable.
-- A genuine security reduction ("legacy compromise doesn't help the
-- adversary because PQC is UF-CMA-secure") would require modeling how
-- `auth.pqcSigned` is actually derived from a `PQCSig.verify` call over an
-- `Adversary`-controlled message/signature pair — that link does not exist
-- yet. Renamed to describe what's actually proved: a direct structural
-- corollary of `postEpochAccepts`, independent of the (currently
-- unconnected) crypto hypotheses.
theorem theorem7_post_epoch_pqc_signed_regardless_of_legacy_compromise
    (auth : MigrationAuth) (h_post : postEpochAccepts auth) :
    auth.pqcSigned = true :=
  h_post.2

theorem theorem7_post_epoch_pqc_signed_regardless_of_pqc_hardness_hypothesis
    (auth : MigrationAuth) (h_post : postEpochAccepts auth) :
    auth.pqcSigned = true :=
  h_post.2

-- Kept for traceability-matrix name compatibility; both now alias the
-- honestly-scoped theorem above rather than pretending to use hypotheses
-- (`legacyCompromised`, `pqcUnforgeable`) that the current model can't yet
-- connect to `postEpochAccepts`.
theorem theorem7_legacy_compromise_insufficient (auth : MigrationAuth)
    (_h_comp : auth.legacyCompromised = true)
    (h_post : postEpochAccepts auth) :
    auth.pqcSigned = true :=
  theorem7_post_epoch_pqc_signed_regardless_of_legacy_compromise auth h_post

/-- Name kept for traceability-matrix compatibility. NOT a PQC-hardness
    security reduction — see the comment above `theorem7_legacy_compromise_insufficient`.
    The `pqcUnforgeable` hypothesis is accepted but unused, and is named
    `_h_pqc_secure` (rather than silently discarded via `have _ := ...`) so
    that stays visible at every call site. -/
theorem theorem7_pqc_hardness_ensures_continuity (auth : MigrationAuth)
    (pqc : PQCSig)
    (oracle : SignOracle)
    (_h_pqc_secure : pqcUnforgeable pqc oracle)
    (h_post : postEpochAccepts auth) :
    auth.pqcSigned = true :=
  theorem7_post_epoch_pqc_signed_regardless_of_pqc_hardness_hypothesis auth h_post

/-! ## A real PQC-hardness reduction

The theorems above are honestly scoped: they don't use `pqcUnforgeable` because
`MigrationAuth.pqcSigned` is a free-standing `Bool` with no link to `PQCSig.verify`.
The lemmas below close that gap for real, additively (nothing above is changed):
`pqcSigned` is only meaningfully "secured" when it's *witnessed* by an actual
signature-verification call, and `pqcUnforgeable` is genuinely used — not
accepted and discarded — to show a witnessed bit can't be forged for a message
the adversary never legitimately queried.

Scope, stated plainly: this shows the reduction is *sound when the acceptance
bit is witnessed*. It does not yet prove that the real Go migration ledger
maintains a witnessed invariant end-to-end (`LedgerTransition` below and the
`goVerifyMigrationSignatureBundle`/`goPostEpochAccept` refinement shims still
treat `pqcSigned` as a free `Bool`, exactly as before) — that's the remaining
gap toward Workstream 4. What's here is genuine, checked cryptographic
content that didn't exist before, not the full end-to-end claim.
-/

/-- The core UF-CMA guarantee, used for real: if `pqc` is UF-CMA-secure
    relative to `oracle`, no adversary can produce a valid signature for a
    message it never queried the oracle for. This is `pqcUnforgeable`
    unfolded into its useful contrapositive form. -/
theorem pqc_unforgeable_no_valid_sig_for_unqueried
    (pqc : PQCSig) (oracle : SignOracle) (h_secure : pqcUnforgeable pqc oracle)
    (queries : List Nat) (msg sig : Nat) (h_fresh : msg ∉ queries) :
    pqc.verify msg sig = false := by
  cases h : pqc.verify msg sig with
  | false => rfl
  | true => exact absurd (h_secure ⟨queries, msg, sig⟩) (not_not.mpr ⟨h, h_fresh⟩)

/-- What it would mean for a `MigrationAuth`'s PQC bit to be *witnessed*:
    backed by an actual signature check against a chosen scheme, message, and
    signature, rather than a free-standing boolean anyone could set. -/
def pqcSignedWitnessed (pqc : PQCSig) (auth : MigrationAuth) (msg sig : Nat) : Prop :=
  auth.pqcSigned = pqc.verify msg sig

/-- Real reduction: an adversary who hasn't obtained a legitimate PQC
    signature for `msg` (never in the oracle's prior `queries`) cannot make a
    *witnessed* `pqcSigned` true for it, given UF-CMA security. Unlike
    `theorem7_pqc_hardness_ensures_continuity` above, `h_secure` is actually
    used here. -/
theorem pqc_hardness_blocks_unwitnessed_acceptance
    (pqc : PQCSig) (oracle : SignOracle) (h_secure : pqcUnforgeable pqc oracle)
    (auth : MigrationAuth) (queries : List Nat) (msg sig : Nat)
    (h_witness : pqcSignedWitnessed pqc auth msg sig)
    (h_fresh : msg ∉ queries) :
    auth.pqcSigned = false := by
  rw [h_witness]
  exact pqc_unforgeable_no_valid_sig_for_unqueried pqc oracle h_secure queries msg sig h_fresh

/-- Corollary: a witnessed-but-unqueried attempt cannot satisfy
    `postEpochAccepts`. A real, hardness-dependent counterpart to
    `theorem7_dual_signature_continuity`'s converse — unlike the purely
    structural theorems above, this one would actually break if PQC weren't
    UF-CMA-secure. -/
theorem pqc_hardness_blocks_unwitnessed_post_epoch_accept
    (pqc : PQCSig) (oracle : SignOracle) (h_secure : pqcUnforgeable pqc oracle)
    (auth : MigrationAuth) (queries : List Nat) (msg sig : Nat)
    (h_witness : pqcSignedWitnessed pqc auth msg sig)
    (h_fresh : msg ∉ queries) :
    ¬ postEpochAccepts auth := by
  intro h
  have h_false := pqc_hardness_blocks_unwitnessed_acceptance pqc oracle h_secure auth queries msg sig
    h_witness h_fresh
  rw [postEpochAccepts] at h
  rw [h_false] at h
  exact absurd h.2 (by decide)

/-- Scale guard for 10M-node profile (native_decide style). -/
theorem theorem7_scale_bound : global_scale ≥ 10000000 := by
  unfold global_scale
  native_decide

theorem theorem7_scale_guard :
    postEpochAccepts { legacySigned := true, pqcSigned := true, legacyCompromised := false } := by
  have _ := theorem7_scale_bound
  simp [postEpochAccepts]

/--
Refinement shim for Go `verifyMigrationSignatureBundle`:
acceptance requires complete dual-signature authorization after migration cutover.
-/
def goVerifyMigrationSignatureBundle (auth : MigrationAuth) : Prop :=
  auth.legacySigned = true ∧ auth.pqcSigned = true

/--
Refinement shim for Go `postEpochAccept` behavior in settlement checks.
This remains intentionally abstract at the Lean model level.
-/
def goPostEpochAccept (auth : MigrationAuth) : Prop :=
  auth.pqcSigned = true

/-- Refinement to Go migration + settlement checks. -/
theorem theorem7_refines_go_migration (auth : MigrationAuth) :
    postEpochAccepts auth →
    (goVerifyMigrationSignatureBundle auth ∧ goPostEpochAccept auth) := by
  intro h
  exact ⟨⟨h.1, h.2⟩, h.2⟩

/-- Go-side dual-signature success implies Lean post-cutover acceptance. -/
theorem theorem7_refines_go_migration_sound (auth : MigrationAuth)
    (h_go : goVerifyMigrationSignatureBundle auth) :
    postEpochAccepts auth := by
  exact ⟨h_go.1, h_go.2⟩

/-- Field-level refinement: Lean acceptance implies each Go-side auth field gate is true. -/
theorem theorem7_refines_go_field_mapping (auth : MigrationAuth)
    (h : postEpochAccepts auth) :
    auth.legacySigned = true ∧ auth.pqcSigned = true := by
  exact ⟨h.1, h.2⟩

end LeanFormalization
