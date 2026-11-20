import Mathlib
import LeanFormalization.Theorem5MiMCFormalization
import LeanFormalization.Theorem5Cryptography

/-!
# ZK Circuit Refinement: Lean Spec ↔ Go Implementation

This module formalizes the correspondence between the Lean specification of
the data-commitment relation (`ZKSpec` / `zkSpecRelation` / `zkSpecVerify`
below) and Go's `VerifyDataCommitmentProof` in
`internal/zksnark_circuit_verifier.go`, and the refinement for the
`WeightUpdateCircuit` production in `internal/zkweight_circuit.go`.

The Go side runs a real Groth16 proof against a circuit-derived verification
key (`dataCommitmentVK`, produced by the MPC setup over the compiled
`DataCommitmentCircuit` R1CS).

## How close the model is

* **MiMC** is the real construction from `Theorem5MiMCFormalization`: a
  110-round keyed block cipher (each round `m ↦ (m + key + c_i)^5`), a
  Miyaguchi–Preneel compressor, and a Merkle–Damgård chain. The statement's
  commitment is a BN254 scalar-field element, as in the circuit. The round
  constants are a parameter (gnark-crypto derives them from a seed by a sha3
  procedure this Mathlib cannot reproduce); the theorems are generic in them.
* **The verification key** is a deterministic, injective function of the
  circuit's structural description (public-input count, witness arity,
  constraint count), not a magic constant — see `deriveVK`. The honest
  derivation would hash the compiled constraint system, which needs curve
  machinery this Mathlib lacks.

## What is deliberately not claimed

The full "accepted proof ⇒ an extractable preimage" direction is Groth16
knowledge soundness for the compiled R1CS. It is NOT proved here and is not
provable in this Mathlib (no pairing or hardness machinery; see
`docs/MAJOR_WIN_PLAN.md` W2/W3). It is recorded as a gap rather than hidden
behind a surrogate hash that makes the existential trivially satisfiable.

Accordingly `zk_impl_refines_spec` carries an explicit hypothesis that the
commitment lies in the image of the one-block hash. Under the previous
identity stand-in that hypothesis was automatic (every non-zero commitment was
its own preimage), which is exactly why the old `zk_spec_verify_iff` was a
triviality theorem; the closer model removes that accident rather than
preserving it.
-/

namespace Refinement

open LeanFormalization

/-! ## `DataCommitmentCircuit` (single-scalar path) -/

/-- The BN254 scalar-field modulus the real circuits hash over. -/
def zkField : Nat := bn254Prime

/-- The MiMC round constants of the Lean model: a deterministic stand-in for
    gnark-crypto's seed-derived constants (see `mimcModelConstants`). -/
def zkMiMCConstants : List (ZMod zkField) := mimcModelConstants zkField

/-- Spec statement: a public commitment (a BN254 scalar-field element) plus the
    circuit-derived VK. -/
structure ZKSpec where
  commitment : ZMod zkField
  vk : Nat

/-- Spec witness: the secret preimage (a field element). -/
structure ZKWitness where
  preimage : ZMod zkField

/-- Spec proof carrier (mirrors Go's serialized proof + public commitment). -/
structure ZKProof where
  commitment : ZMod zkField
  vk_binding : Nat

/-- Spec relation: `Commitment = MiMC(Preimage)` under the real one-block MiMC
    hash, and the commitment is non-zero. Mirrors
    `DataCommitmentCircuit.Define`. -/
def zkSpecRelation (stmt : ZKSpec) (w : ZKWitness) : Prop :=
  mimcHashOneBlock zkField mimcExponent zkMiMCConstants w.preimage = stmt.commitment ∧
    stmt.commitment ≠ 0

/-- Spec verifier: accepts iff a witness satisfying the relation exists. -/
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
  ⟨mimcHashOneBlock zkField mimcExponent zkMiMCConstants w.preimage, stmt.vk⟩

/-- Exact characterisation of the spec's existence claim: a statement is
    satisfiable iff its commitment is non-zero and is in the image of the
    one-block hash. This replaces the old identity-stand-in theorem
    (`zkSpecVerify stmt ↔ stmt.commitment ≠ 0`), which was a triviality. -/
theorem zk_spec_verify_iff (stmt : ZKSpec) :
    zkSpecVerify stmt ↔
      stmt.commitment ≠ 0 ∧
        stmt.commitment ∈ Set.range (mimcHashOneBlock zkField mimcExponent zkMiMCConstants) := by
  constructor
  · rintro ⟨w, h1, h2⟩
    exact ⟨h2, w.preimage, h1⟩
  · rintro ⟨hne, x, hx⟩
    exact ⟨⟨x⟩, hx, hne⟩

/-- Refinement (soundness): an accepted proof implies the statement is
    satisfiable, **provided the commitment lies in the image of the one-block
    hash**. That hypothesis is automatic for the old identity stand-in and is
    exactly the content Groth16 knowledge soundness would supply for the real
    circuit; it is stated, not hidden. -/
theorem zk_impl_refines_spec (stmt : ZKSpec) (proof : ZKProof)
    (h : zkImplVerify stmt proof = true)
    (himg : ∃ x : ZMod zkField,
      mimcHashOneBlock zkField mimcExponent zkMiMCConstants x = stmt.commitment) :
    zkSpecVerify stmt := by
  rw [zk_impl_accept_iff] at h
  obtain ⟨-, -, -, hne⟩ := h
  obtain ⟨x, hx⟩ := himg
  exact ⟨⟨x⟩, hx, hne⟩

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
  rw [zk_impl_accept_iff] at h1 h2
  exact h1.1.trans h2.1.symm

/-- Small-prime guard for the MiMC round function, delegating to the formalized
    result in `Theorem5MiMCFormalization`. -/
theorem zk_mimc_real_round_injective :
    Function.Injective (mimcRound 7 5 (0 : ZMod 7)) :=
  mimcRound_small_prime_guard

/-- Under the real MiMC round function, a commitment has at most one preimage
    (small-prime guard). -/
theorem zk_preimage_unique (a b : ZMod 7)
    (hh : mimcRound 7 5 (0 : ZMod 7) a = mimcRound 7 5 (0 : ZMod 7) b) :
    a = b :=
  zk_mimc_real_round_injective hh

/-- The BN254 MiMC block cipher is a permutation, so a digest has exactly one
    preimage under it. This is the non-trivial algebraic content the identity
    stand-in lacked. -/
theorem zk_block_cipher_preimage_unique (hp : Nat.Prime zkField) (digest : ZMod zkField) :
    ∃! m, mimcEncrypt zkField mimcExponent (0 : ZMod zkField) zkMiMCConstants m = digest :=
  mimcEncrypt_preimage_unique zkField mimcExponent hp bn254Exponent_coprime (by decide)
    (0 : ZMod zkField) zkMiMCConstants digest

/-- Uniqueness of the BN254 block-cipher preimage, stated as injectivity. -/
theorem zk_preimage_unique_bn254 (hp : Nat.Prime zkField) (a b : ZMod zkField)
    (hh : mimcEncrypt zkField mimcExponent (0 : ZMod zkField) zkMiMCConstants a
        = mimcEncrypt zkField mimcExponent (0 : ZMod zkField) zkMiMCConstants b) :
    a = b :=
  mimcEncrypt_injective zkField mimcExponent hp bn254Exponent_coprime (by decide)
    (0 : ZMod zkField) zkMiMCConstants hh

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
behind a surrogate hash that makes the existential trivially satisfiable.
-/

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
