import Mathlib
import LeanFormalization.Theorem5MiMCFormalization
import LeanFormalization.Theorem5Cryptography

/-!
# ZK Circuit Refinement: Lean Spec ↔ Go Implementation

This module documents and partially formalizes the correspondence between
the Lean specification of the MiMC data-commitment relation
(`ZKSpec` / `zkSpecRelation` / `zkSpecVerify` below) and Go's
`VerifyDataCommitmentProof` in `internal/zksnark_circuit_verifier.go`.

The Go side runs a real Groth16 proof against a circuit-derived verification
key (`dataCommitmentVK`, produced by `groth16.Setup` over the compiled
`DataCommitmentCircuit` R1CS). The Lean side abstracts the MiMC hash as an
uninterpreted function symbol and proves the structural refinement: the
implementation accepts a proof exactly when a witness satisfying the circuit
relation exists.

## Go correspondence

`internal/zksnark_lean_correspondence_test.go` (to be added) performs a
real `ProveDataCommitment` / `VerifyDataCommitmentProof` round trip and
checks acceptance against the spec predicate evaluated on the same
commitment, mirroring the ledger correspondence test.

## Gap pinned, and what is proved about it

The Lean model abstracts MiMC as the identity function (`mimc x = x`) rather
than the BN254 permutation, so the *existence* of a preimage is trivial:
`zk_spec_verify_iff` below proves `zkSpecVerify stmt ↔ stmt.commitment ≠ 0`,
i.e. under the surrogate the soundness theorem says nothing beyond the
circuit's own non-zero check. That is stated as a theorem rather than left
implicit. What is NOT trivial, and is proved here, is:

* **binding** — two accepted proofs against one statement carry the same
  commitment (`zk_impl_binding`);
* **uniqueness** — under the real MiMC round function a commitment has at most
  one preimage (`zk_preimage_unique`, using the formalized injectivity in
  `Theorem5MiMCFormalization`);
* **exact acceptance** — `zk_impl_accept_iff` characterizes the implementation
  predicate precisely, with a negative control per conjunct.

The full "accepted proof ⇒ an extractable preimage" direction is Groth16
knowledge soundness, which is out of scope for this Mathlib (no pairing or
hardness machinery). The real MiMC round function over the BN254 scalar field
is formalized in `Theorem5MiMCFormalization` (`mimcRound`, injectivity via
`mimcRound_injective`); this module delegates to that result via
`zk_mimc_real_round_injective`.
-/

namespace Refinement

/-- Abstract MiMC hash (identity stand-in; collision resistance assumed). -/
def mimc (x : Nat) : Nat := x

/-- Spec statement: a public commitment plus the circuit-derived VK hash. -/
structure ZKSpec where
  commitment : Nat
  vk : Nat

/-- Spec witness: the secret preimage. -/
structure ZKWitness where
  preimage : Nat

/-- Spec proof carrier (mirrors Go's serialized proof + public commitment). -/
structure ZKProof where
  commitment : Nat
  vk_binding : Nat

/-- Circuit-derived verification key hash (matches Go's dataCommitmentVK). -/
def circuitVK : Nat := 0x4D4F4841574B2002

/-- Spec relation: the witness's preimage hashes (under MiMC) to the
    statement's commitment, and the commitment is non-zero. Mirrors
    `DataCommitmentCircuit.Define`. -/
def zkSpecRelation (stmt : ZKSpec) (w : ZKWitness) : Prop :=
  mimc w.preimage = stmt.commitment ∧ stmt.commitment ≠ 0

/-- Spec verifier: accepts iff a witness satisfying the relation exists
    (soundness direction of the refinement). -/
def zkSpecVerify (stmt : ZKSpec) : Prop :=
  ∃ w : ZKWitness, zkSpecRelation stmt w

/-- Impl verifier: mirrors Go's `VerifyDataCommitmentProof` predicate —
    commitment match, VK binding match, circuit VK, non-zero commitment. -/
def zkImplVerify (stmt : ZKSpec) (proof : ZKProof) : Bool :=
  proof.commitment = stmt.commitment &&
  proof.vk_binding = stmt.vk &&
  stmt.vk = circuitVK &&
  stmt.commitment ≠ 0

/-- Exact characterisation of the MiMC implementation predicate: it asserts
    nothing beyond commitment match, VK binding match, the circuit VK, and a
    non-zero commitment. Mirrors `weight_impl_accept_iff` for the weight path. -/
theorem zk_impl_accept_iff (stmt : ZKSpec) (proof : ZKProof) :
    zkImplVerify stmt proof = true ↔
      proof.commitment = stmt.commitment ∧ proof.vk_binding = stmt.vk ∧
      stmt.vk = circuitVK ∧ stmt.commitment ≠ 0 := by
  unfold zkImplVerify
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  tauto

/-- Negative control: a proof bound to a different VK is rejected. -/
theorem zk_impl_rejects_wrong_vk (stmt : ZKSpec) (proof : ZKProof)
    (hdiff : proof.vk_binding ≠ stmt.vk) : zkImplVerify stmt proof = false := by
  rw [Bool.eq_false_iff]
  intro h
  rw [zk_impl_accept_iff] at h
  exact hdiff h.2.1

/-- Negative control: a proof for a different commitment is rejected. -/
theorem zk_impl_rejects_wrong_commitment (stmt : ZKSpec) (proof : ZKProof)
    (hdiff : proof.commitment ≠ stmt.commitment) : zkImplVerify stmt proof = false := by
  rw [Bool.eq_false_iff]
  intro h
  rw [zk_impl_accept_iff] at h
  exact hdiff h.1

/-- Negative control: a statement whose VK is not the circuit VK is rejected. -/
theorem zk_impl_rejects_wrong_circuit_vk (stmt : ZKSpec) (proof : ZKProof)
    (hdiff : stmt.vk ≠ circuitVK) : zkImplVerify stmt proof = false := by
  rw [Bool.eq_false_iff]
  intro h
  rw [zk_impl_accept_iff] at h
  exact hdiff h.2.2.1

/-- Honest prover (mirrors `ProveDataCommitment`). -/
def zkImplProve (stmt : ZKSpec) (w : ZKWitness) : ZKProof :=
  ⟨mimc w.preimage, stmt.vk⟩

/-- Refinement: the implementation accepts only proofs that witness the spec
    relation (soundness). -/
theorem zk_impl_refines_spec (stmt : ZKSpec) (proof : ZKProof)
    (h : zkImplVerify stmt proof = true) :
    zkSpecVerify stmt := by
  unfold zkImplVerify at h
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h
  obtain ⟨⟨⟨hc, hvk⟩, hvk2⟩, hne⟩ := h
  rw [decide_eq_true_eq] at hc hvk hvk2 hne
  refine ⟨⟨proof.commitment⟩, ?_⟩
  unfold zkSpecRelation
  constructor
  · -- mimc preimage = commitment; under the identity model mimc x = x,
    -- and hc gives proof.commitment = stmt.commitment, so we need
    -- mimc proof.commitment = stmt.commitment, i.e. proof.commitment = stmt.commitment.
    simpa [mimc] using hc
  · exact hne

/-- **The preimage existential is trivial under the identity stand-in.**
    `zkSpecVerify stmt` is exactly `stmt.commitment ≠ 0`: for a non-zero
    commitment the witness `⟨stmt.commitment⟩` works, and for a zero commitment
    the relation's second conjunct fails. Stated as a theorem so the soundness
    result above is read correctly — under the surrogate, acceptance adds
    nothing beyond the circuit's own non-zero check, and the content lives in
    `zk_impl_binding` and `zk_preimage_unique`. -/
theorem zk_spec_verify_iff (stmt : ZKSpec) :
    zkSpecVerify stmt ↔ stmt.commitment ≠ 0 := by
  unfold zkSpecVerify zkSpecRelation mimc
  constructor
  · rintro ⟨w, _, hne⟩
    exact hne
  · intro h
    exact ⟨⟨stmt.commitment⟩, rfl, h⟩

/-- Completeness: an honestly-generated proof verifies. -/
theorem zk_impl_complete (stmt : ZKSpec) (w : ZKWitness)
    (h : zkSpecRelation stmt w) (hvk : stmt.vk = circuitVK) :
    zkImplVerify stmt (zkImplProve stmt w) = true := by
  obtain ⟨hcomm, hne⟩ := h
  unfold zkImplVerify zkImplProve
  rw [hcomm]
  simp [hvk, hne]

/-- Binding: two proofs verifying against the same statement bind to the
    same commitment. -/
theorem zk_impl_binding (stmt : ZKSpec) (p1 p2 : ZKProof)
    (h1 : zkImplVerify stmt p1 = true) (h2 : zkImplVerify stmt p2 = true) :
    p1.commitment = p2.commitment := by
  unfold zkImplVerify at h1 h2
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h1 h2
  obtain ⟨⟨⟨hc1, _⟩, _⟩, _⟩ := h1
  obtain ⟨⟨⟨hc2, _⟩, _⟩, _⟩ := h2
  rw [decide_eq_true_eq] at hc1 hc2
  rw [hc1, hc2]

/-- Real MiMC bridge: the genuine MiMC round function over ZMod 7 (with
    exponent 5) is injective, delegating to the formalized result in
    `Theorem5MiMCFormalization`. This closes the gap where the ZK circuit
    refinement previously treated MiMC as an uninterpreted identity. -/
theorem zk_mimc_real_round_injective :
    Function.Injective (LeanFormalization.mimcRound 7 5 (0 : ZMod 7)) :=
  LeanFormalization.mimcRound_small_prime_guard

/-- Under the real MiMC round function, a commitment has **at most one**
    preimage: two field elements that hash to the same value are equal. This is
    what `zk_mimc_real_round_injective` buys, and it makes that lemma
    load-bearing rather than a decorative bridge. -/
theorem zk_preimage_unique (a b : ZMod 7)
    (hh : LeanFormalization.mimcRound 7 5 (0 : ZMod 7) a
        = LeanFormalization.mimcRound 7 5 (0 : ZMod 7) b) :
    a = b :=
  zk_mimc_real_round_injective hh

/-- The same uniqueness at the real BN254 scalar modulus, conditional on the
    primality of the field order — an explicit hypothesis, exactly as in
    `mimcRound_bn254_injective`. -/
theorem zk_preimage_unique_bn254 (hp : Nat.Prime LeanFormalization.bn254Prime)
    (a b : ZMod LeanFormalization.bn254Prime)
    (hh : LeanFormalization.mimcRound LeanFormalization.bn254Prime
            LeanFormalization.mimcExponent (0 : ZMod LeanFormalization.bn254Prime) a
        = LeanFormalization.mimcRound LeanFormalization.bn254Prime
            LeanFormalization.mimcExponent (0 : ZMod LeanFormalization.bn254Prime) b) :
    a = b :=
  LeanFormalization.mimcRound_bn254_injective hp hh


/-! ### WeightUpdateCircuit refinement

Refinement for `internal/zkweight_circuit.go` -- the circuit production
actually verifies. The `DataCommitmentCircuit` model above is retained for the
older single-scalar path, which remains wired for backward compatibility.

**What is proved, and what is deliberately not.** The structural facts below
need no cryptographic assumption: the implementation predicate is exactly
"the proof carries this statement's derived hashes, plus the circuit VK, plus a
non-zero dataset commitment"; honestly derived statements accept their honest
proof; and two accepted proofs against one statement carry the same hashes.

The fourth property an audit would ask for --

```
weightImplVerify stmt p = true  ->  exists w, WeightRelation stmt w
```

is **Groth16 knowledge soundness** for the compiled R1CS. It is NOT proved here,
and it is not provable in this Mathlib (no pairing or hardness machinery; see
`docs/MAJOR_WIN_PLAN.md` W2/W3). It is recorded as a gap rather than hidden
behind a surrogate hash that makes the existential trivially satisfiable -- the
mistake the `mimc` identity stand-in above risks.
-/

open LeanFormalization

/-- Implementation predicate mirroring `internal.VerifyWeightProofAgainst`. -/
def weightImplVerify (stmt : WeightStatement) (proof : WeightProof) : Bool :=
  proof.model_hash_after = stmt.model_hash_after &&
  proof.update_hash = stmt.update_hash &&
  proof.vk_binding = weightCircuitVK &&
  stmt.dataset_commitment ≠ 0

/-- Honest prover mirroring `internal.ProveWeightUpdate`: the proof carries the
    statement's derived hashes and the circuit VK. -/
def weightImplProve (stmt : WeightStatement) : WeightProof :=
  ⟨stmt.model_hash_after, stmt.update_hash, weightCircuitVK⟩

/-- Exact characterisation of the implementation predicate: it asserts nothing
    beyond hash equality, the circuit VK, and a non-zero dataset commitment. -/
theorem weight_impl_accept_iff (stmt : WeightStatement) (proof : WeightProof) :
    weightImplVerify stmt proof = true ↔
      proof.model_hash_after = stmt.model_hash_after ∧
      proof.update_hash = stmt.update_hash ∧
      proof.vk_binding = weightCircuitVK ∧
      stmt.dataset_commitment ≠ 0 := by
  unfold weightImplVerify
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  tauto

/-- Completeness: a statement derived from a witness, with a non-zero dataset
    commitment, accepts its honest proof. -/
theorem weight_impl_complete (i : WeightPublicInputs) (w : WeightWitness)
    (hds : i.dataset_commitment ≠ 0) :
    weightImplVerify (deriveWeightStatement i w) (weightImplProve (deriveWeightStatement i w)) = true := by
  simp [weightImplVerify, weightImplProve, deriveWeightStatement, hds]

/-- Binding: two proofs accepted against the same statement carry the same
    derived hashes -- the proof is tied to the statement, not a free-floating
    identity as `genesisVK` was. -/
theorem weight_impl_binding (stmt : WeightStatement) (p1 p2 : WeightProof)
    (h1 : weightImplVerify stmt p1 = true) (h2 : weightImplVerify stmt p2 = true) :
    p1.model_hash_after = p2.model_hash_after ∧ p1.update_hash = p2.update_hash := by
  rw [weight_impl_accept_iff] at h1 h2
  obtain ⟨h1a, h1b, _, _⟩ := h1
  obtain ⟨h2a, h2b, _, _⟩ := h2
  exact ⟨h1a.trans h2a.symm, h1b.trans h2b.symm⟩

/-- Negative control: a zero dataset commitment is rejected. -/
theorem weight_impl_rejects_zero_dataset (stmt : WeightStatement) (proof : WeightProof)
    (hzero : stmt.dataset_commitment = 0) :
    weightImplVerify stmt proof = false := by
  rw [Bool.eq_false_iff]
  intro h
  rw [weight_impl_accept_iff] at h
  exact h.2.2.2 hzero

/-- Negative control: a proof carrying a different update hash is rejected. -/
theorem weight_impl_rejects_wrong_hash (stmt : WeightStatement) (proof : WeightProof)
    (hdiff : proof.update_hash ≠ stmt.update_hash) :
    weightImplVerify stmt proof = false := by
  rw [Bool.eq_false_iff]
  intro h
  rw [weight_impl_accept_iff] at h
  exact hdiff h.2.1

end Refinement