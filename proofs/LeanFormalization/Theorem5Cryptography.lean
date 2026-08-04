import Mathlib
import LeanFormalization.Common

namespace LeanFormalization

/- Strategy:
  Keep the cryptographic claims abstract and prove scale-invariant verifier
  behavior from a constant-cost pairing model.

  Tactics used:
  - `rfl` for model equalities
  - `simp` for verifier and cost normalization
  - `norm_num` and `native_decide` for concrete scale guards

  Future work:
  Extend the abstract verifier story with hybrid proof accounting and size-
  aware runtime measurements.
-/

/-- Abstract zk-SNARK statement structure
    Represents the public input/claim that a proof attests to.
-/
structure ZKStatement where
  claim_id : Nat
  claim_digest : Nat

/-- Abstract zk-SNARK witness structure
    Represents secret data that proves the statement without revealing it.
-/
structure ZKWitness where
  claim_digest : Nat
  internal_data : Nat

/-- Abstract zk-SNARK proof structure
    Represents the cryptographic evidence.
-/
structure ZKProof where
  proof_payload : Nat

/-- Abstract witness-relation: does `w` actually witness `stmt`? Deliberately
    abstract (digest matching, not real circuit satisfiability) — this
    models the *shape* of a soundness/completeness relationship, not a
    cryptographic hardness assumption; full Groth16/q-SDH formalization
    is out of scope (see the caveat on `theorem5_verifyops_constant`
    below, formerly misnamed `theorem5_qsdh_security`). Replaces the
    previous `statementSoundness`, whose own witness-existence claim was
    always trivially satisfiable for any `stmt` (build `⟨stmt.claim_digest, 1⟩`)
    and was never actually checked against anything a verifier does. -/
def Relation (stmt : ZKStatement) (w : ZKWitness) : Prop :=
  w.claim_digest = stmt.claim_digest ∧ w.claim_digest ≠ 0

/-- Abstract proof generation from a witness. -/
def prove (_stmt : ZKStatement) (w : ZKWitness) : ZKProof :=
  ⟨w.claim_digest⟩

/-- Verifier: genuinely depends on the statement being verified. The
    previous version (`proof.proof_payload ≠ 0`, `_stmt` unused) accepted
    *any* nonzero-payload proof for *any* statement whatsoever — meaning
    "the verifier accepts a proof of statement A" and "...of statement B"
    were the same claim, and `theorem5_verifier_completeness` below was
    provable by fabricating an unrelated payload, never using its own `_w`
    parameter. Fixed by checking the proof payload actually matches the
    statement. -/
def verify (stmt : ZKStatement) (proof : ZKProof) : Bool :=
  proof.proof_payload = stmt.claim_digest && proof.proof_payload ≠ 0

/-- Constant proof-size model in bytes. -/
def proofSize (_participants : Nat) : Nat := 200

/-- Constant verifier operation model (pairing checks). -/
def verifyOps (_participants : Nat) : Nat := 3

/-- A simple verifier runtime proxy from operation count and constant cost. -/
def verifyCostMicros (participants : Nat) : Nat :=
  verifyOps participants * 1000

/-- Proof size remains constant across scale. -/
theorem theorem5_constant_size (n m : Nat) :
    proofSize n = proofSize m := by
  rfl

/-- Verification operation count remains constant across scale. -/
theorem theorem5_constant_ops (n m : Nat) :
    verifyOps n = verifyOps m := by
  rfl

/-- Runtime proxy is scale invariant under the constant-operation verifier model. -/
theorem theorem5_constant_cost (n m : Nat) :
    verifyCostMicros n = verifyCostMicros m := by
  simp [verifyCostMicros, verifyOps]

/-- Concrete latency guard modeled as bounded operation count. -/
theorem theorem5_ops_guard : verifyOps 10000000 <= 10 := by
  native_decide

/-- Concrete runtime guard for the 10M-node profile in this model. -/
theorem theorem5_cost_guard : verifyCostMicros 10000000 <= 10000 := by
  native_decide

/-- Theorem 5a: Verifier soundness — the direction that actually matters for
    security ("can a cheating prover fool the verifier?"): if `verify`
    accepts a proof for `stmt`, a real witness satisfying `Relation stmt`
    exists. The previous `theorem5_proof_soundness` didn't test this at
    all — it showed a witness always exists for *any* statement (trivially
    true, since `Relation`-style matching is satisfiable by construction),
    which is the wrong direction and doesn't depend on `verify` or any
    proof in any way; its own `stmt.claim_id < n` hypothesis was discarded
    unused. -/
theorem theorem5_verifier_soundness (stmt : ZKStatement) (proof : ZKProof)
    (h : verify stmt proof = true) :
    ∃ w, Relation stmt w := by
  unfold verify at h
  rw [Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨heq, hne⟩ := h
  refine ⟨⟨proof.proof_payload, 1⟩, heq, ?_⟩
  simpa using hne

/-- Theorem 5b: Verifier completeness — an honestly-generated proof from a
    real witness verifies. The previous version took `_w : ZKWitness` and
    never used it (underscore-prefixed at the call site, a tell): it proved
    "some proof exists that verify accepts" by fabricating an unrelated
    payload, not "the proof generated from *this* witness verifies." Now
    genuinely depends on `w` via `Relation` and `prove`. -/
theorem theorem5_verifier_completeness (stmt : ZKStatement) (w : ZKWitness)
    (h : Relation stmt w) :
    verify stmt (prove stmt w) = true := by
  obtain ⟨heq, hne⟩ := h
  unfold verify prove
  rw [heq] at hne
  simp [heq, hne]

/-- Theorem 5c: Proof size independence.
    The proof size doesn't scale with witness size or statement count. -/
theorem theorem5_proof_size_independence (n : Nat) :
    proofSize n = 200 := by
  simp [proofSize]

/-- Constant verifier operation count, restated as its own theorem for
    traceability-matrix compatibility with the removed
    `theorem5_qsdh_security`.

    RENAMED, NOT JUST REDOCUMENTED: the previous name and docstring claimed
    "the constant-operation verifier is sound under the q-SDH security
    model: successful forgery requires computing a discrete log..." — but
    the actual theorem (`∀ n, verifyOps n = 3 ∧ verifyOps n ≤ 10`) is pure
    arithmetic about a constant function; it does not mention forgery,
    discrete logs, pairing groups, or any hardness assumption, and proves
    nothing about q-SDH. This was the single most misleading name in this
    file — a security-sounding label on a content-free restatement of
    `theorem5_constant_ops`. A genuine q-SDH-hardness reduction is out of
    scope for this pass (full Groth16/q-SDH formalization, per the project's
    formal-verification plan) and is not attempted here; what's real is
    just that the operation count is the constant `3`. -/
theorem theorem5_verifyops_constant : ∀ n : Nat, verifyOps n = 3 ∧ verifyOps n ≤ 10 := by
  intro n
  simp [verifyOps]

end LeanFormalization
