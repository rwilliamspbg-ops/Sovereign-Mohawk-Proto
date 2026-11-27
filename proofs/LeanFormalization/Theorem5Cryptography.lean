import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem5MiMCFormalization

namespace LeanFormalization

/- Strategy:
  Keep the cryptographic claims abstract and prove scale-invariant verifier
  behavior from a constant-cost pairing model.

  Tactics used:
  - `rfl` for model equalities
  - `simp` for verifier and cost normalization
  - `norm_num` for concrete scale guards

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

/-- Genesis Identity Verification Key hash constant (reconciling genesis identity bindings). -/
def GenesisIdentityVK : Nat := 0x4D4F4841574B1001

/-- Circuit-Bound zk-SNARK Statement structure.
    Represents public data commitment digest and genesis verification key binding.
-/
structure CircuitBoundStatement where
  claim_id : Nat
  data_commitment_digest : Nat
  vk_hash : Nat

/-- Circuit-Bound zk-SNARK Witness structure.
    Represents preimage witness data satisfying circuit constraints.
-/
structure CircuitBoundWitness where
  preimage_data : Nat
  commitment_digest : Nat

/-- Circuit-Bound zk-SNARK Proof structure. -/
structure CircuitBoundProof where
  proof_payload : Nat
  vk_binding : Nat

/-- Circuit relation: witness commitment matches statement commitment and statement
    vk_hash matches the genesis identity key binding. -/
def CircuitBoundRelation (stmt : CircuitBoundStatement) (w : CircuitBoundWitness) : Prop :=
  w.commitment_digest = stmt.data_commitment_digest ∧
  stmt.vk_hash = GenesisIdentityVK ∧
  w.commitment_digest ≠ 0

/-- Prove circuit-bound statement from witness. -/
def proveCircuitBound (_stmt : CircuitBoundStatement) (w : CircuitBoundWitness) : CircuitBoundProof :=
  ⟨w.commitment_digest, GenesisIdentityVK⟩

/-- Circuit-bound verifier: enforces both proof payload matching data commitment digest
    and genesis identity verification key binding. -/
def verifyCircuitBound (stmt : CircuitBoundStatement) (proof : CircuitBoundProof) : Bool :=
  proof.proof_payload = stmt.data_commitment_digest &&
  proof.vk_binding = stmt.vk_hash &&
  stmt.vk_hash = GenesisIdentityVK &&
  proof.proof_payload ≠ 0

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
  simp [verifyOps]

/-- Concrete runtime guard for the 10M-node profile in this model. -/
theorem theorem5_cost_guard : verifyCostMicros 10000000 <= 10000 := by
  simp [verifyCostMicros, verifyOps]

/-- Theorem 5a: Verifier soundness — the direction that actually matters for
    security ("can a cheating prover fool the verifier?"): if `verify`
    accepts a proof for `stmt`, a real witness satisfying `Relation stmt`
    exists. -/
theorem theorem5_verifier_soundness (stmt : ZKStatement) (proof : ZKProof)
    (h : verify stmt proof = true) :
    ∃ w, Relation stmt w := by
  unfold verify at h
  rw [Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨heq, hne⟩ := h
  refine ⟨⟨proof.proof_payload, 1⟩, heq, ?_⟩
  simpa using hne

/-- Theorem 5b: Verifier completeness — an honestly-generated proof from a
    real witness verifies. -/
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

/-- Theorem 5d: Circuit-bound zk-SNARK verifier completeness under genesis identity binding. -/
theorem theorem5_circuit_bound_completeness (stmt : CircuitBoundStatement) (w : CircuitBoundWitness)
    (h : CircuitBoundRelation stmt w) :
    verifyCircuitBound stmt (proveCircuitBound stmt w) = true := by
  obtain ⟨hcomm, hvk, hne⟩ := h
  unfold verifyCircuitBound proveCircuitBound
  rw [hcomm] at hne
  simp [hcomm, hvk, hne, GenesisIdentityVK]

/-- Theorem 5e: Circuit-bound zk-SNARK verifier soundness under genesis identity binding. -/
theorem theorem5_circuit_bound_soundness (stmt : CircuitBoundStatement) (proof : CircuitBoundProof)
    (h : verifyCircuitBound stmt proof = true) :
    ∃ w, CircuitBoundRelation stmt w := by
  unfold verifyCircuitBound at h
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h
  obtain ⟨⟨⟨hpayload, hvk1⟩, hvk2⟩, hne⟩ := h
  rw [decide_eq_true_eq] at hpayload hvk1 hvk2 hne
  refine ⟨⟨proof.proof_payload, proof.proof_payload⟩, ?_⟩
  unfold CircuitBoundRelation
  have hcomm : proof.proof_payload = stmt.data_commitment_digest := hpayload
  exact ⟨hcomm, hvk2, hne⟩

/-- Constant verifier operation count, restated as its own theorem for
    traceability-matrix compatibility. -/
theorem theorem5_verifyops_constant : ∀ n : Nat, verifyOps n = 3 ∧ verifyOps n ≤ 10 := by
  intro n
  simp [verifyOps]


/-- A structural description of a compiled circuit. -/
structure CircuitDescription where
  publicInputCount : Nat
  witnessArity : Nat
  constraintCount : Nat
  deriving Repr, DecidableEq

/-- The verification-key identity, derived deterministically from the circuit
    description by an injective encoding. Surrogate: the honest derivation is a
    canonical hash of the compiled constraint system, which this Mathlib cannot
    compute (no pairing or curve machinery). What the refinement needs is that
    the key is a *function of the circuit*, so binding to the key is binding to
    the circuit. -/
def deriveVK (c : CircuitDescription) : Nat :=
  Nat.pair (Nat.pair c.publicInputCount c.witnessArity) c.constraintCount

/-- Distinct circuit descriptions have distinct verification keys. -/
theorem deriveVK_injective : Function.Injective deriveVK := by
  intro a b h
  have h1 : Nat.pair a.publicInputCount a.witnessArity =
      Nat.pair b.publicInputCount b.witnessArity := (Nat.pair_eq_pair.mp h).1
  have hb : a.constraintCount = b.constraintCount := (Nat.pair_eq_pair.mp h).2
  have h2 := Nat.pair_eq_pair.mp h1
  cases a; cases b
  simp only [deriveVK] at h
  rw [Nat.pair_eq_pair] at h
  rw [Nat.pair_eq_pair] at h
  obtain ⟨⟨hpc, hwa⟩, hcc⟩ := h
  simp [hpc, hwa, hcc]

/-- The compiled `DataCommitmentCircuit`'s structural description: one public
    input (the commitment), one witness (the preimage), and 331 constraints --
    the last measured from the real compiled circuit. -/
def dataCommitmentCircuitDescription : CircuitDescription :=
  { publicInputCount := 1, witnessArity := 1, constraintCount := 331 }

/-- The `DataCommitmentCircuit` verification key, derived from its structural
    description. In the Go runtime this is the `groth16.VerifyingKey` produced by
    the MPC setup over the compiled R1CS; it is NOT the genesis identity key. -/
def circuitVK : Nat := deriveVK dataCommitmentCircuitDescription

/-- MiMC-bound statement: public commitment (a BN254 scalar-field element)
    plus the circuit-derived VK. -/
structure MiMCStatement where
  commitment : ZMod bn254Prime
  vk : Nat

/-- MiMC witness: the secret preimage (a field element). -/
structure MiMCWitness where
  preimage : ZMod bn254Prime

/-- MiMC proof: carries the commitment it binds to (mirrors the Go proof's
    public commitment). -/
structure MiMCProof where
  commitment : ZMod bn254Prime
  vk_binding : Nat

/-- MiMC circuit relation: `Commitment = MiMC(Preimage)` under the real
    one-block MiMC hash, and the commitment is non-zero. Mirrors
    `DataCommitmentCircuit.Define`. -/
def MiMCRelation (stmt : MiMCStatement) (w : MiMCWitness) : Prop :=
  mimcHashOneBlock bn254Prime mimcExponent (mimcModelConstants bn254Prime) w.preimage =
    stmt.commitment ∧ stmt.commitment ≠ 0

/-- Honest prover: computes the commitment off-circuit (MiMC(preimage)) and
    binds the proof to the circuit VK, mirroring `ProveDataCommitment`. -/
def proveMiMC (stmt : MiMCStatement) (w : MiMCWitness) : MiMCProof :=
  ⟨mimcHashOneBlock bn254Prime mimcExponent (mimcModelConstants bn254Prime) w.preimage,
    stmt.vk⟩

/-- Verifier: accepts iff the proof's commitment matches the statement's
    commitment, the VK binding matches the statement's VK, and the statement
    uses the circuit-derived VK. Mirrors `VerifyDataCommitmentProof`. -/
def verifyMiMC (stmt : MiMCStatement) (proof : MiMCProof) : Bool :=
  proof.commitment = stmt.commitment &&
  proof.vk_binding = stmt.vk &&
  stmt.vk = circuitVK &&
  stmt.commitment ≠ 0

/-- MiMC soundness: an accepted proof implies a real witness (preimage)
    satisfying the circuit relation, **provided the commitment lies in the
    image of the one-block hash**. Under the old identity stand-in that
    hypothesis was automatic; for the real hash it is exactly the content
    Groth16 knowledge soundness would supply, so it is stated rather than
    hidden. -/
theorem theorem5_mimc_soundness (stmt : MiMCStatement) (proof : MiMCProof)
    (h : verifyMiMC stmt proof = true)
    (himg : ∃ x : ZMod bn254Prime,
      mimcHashOneBlock bn254Prime mimcExponent (mimcModelConstants bn254Prime) x =
        stmt.commitment) :
    ∃ w : MiMCWitness, MiMCRelation stmt w := by
  unfold verifyMiMC at h
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h
  obtain ⟨⟨⟨hc, hvk⟩, hvk2⟩, hne⟩ := h
  rw [decide_eq_true_eq] at hc hvk hvk2 hne
  obtain ⟨x, hx⟩ := himg
  exact ⟨⟨x⟩, hx, hne⟩

/-- MiMC completeness: an honestly-generated proof from a real witness
    verifies. -/
theorem theorem5_mimc_completeness (stmt : MiMCStatement) (w : MiMCWitness)
    (h : MiMCRelation stmt w) (hvk : stmt.vk = circuitVK) :
    verifyMiMC stmt (proveMiMC stmt w) = true := by
  obtain ⟨hcomm, hne⟩ := h
  unfold verifyMiMC proveMiMC
  rw [hcomm]
  simp [hvk, hne]

/-- MiMC binding: two proofs verifying against the same statement bind to the
    same commitment. -/
theorem theorem5_mimc_binding (stmt : MiMCStatement) (p1 p2 : MiMCProof)
    (h1 : verifyMiMC stmt p1 = true) (h2 : verifyMiMC stmt p2 = true) :
    p1.commitment = p2.commitment := by
  unfold verifyMiMC at h1 h2
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h1 h2
  obtain ⟨⟨⟨hc1, _⟩, _⟩, _⟩ := h1
  obtain ⟨⟨⟨hc2, _⟩, _⟩, _⟩ := h2
  rw [decide_eq_true_eq] at hc1 hc2
  rw [hc1, hc2]

/-! ### WeightUpdateCircuit (Pillar 1)

Models `internal/zkweight_circuit.go`. As with `mimc` above, the hash is a
deterministic surrogate fold, not the concrete BN254 MiMC permutation; what is
modelled -- and what the theorems below check -- is the **circuit relation**,
i.e. which (statement, witness) pairs the constraint system accepts.
Groth16/q-SDH soundness of the proof system itself is not formalized here
(same scope limit as `Relation` above). -/

/-- Surrogate for the in-circuit MiMC chain: a deterministic left fold over the
field elements written to the hasher, from the zero initial state. -/
def weightHash (xs : List Nat) : Nat := xs.foldl (fun acc x => acc * 31 + x) 0

/-- Squared L2 norm of a gradient vector in the circuit's fixed-point encoding. -/
def sumSq (xs : List Nat) : Nat := (xs.map (fun g => g * g)).sum

/-- Caller-supplied public values (the derived hashes are computed, not given). -/
structure WeightPublicInputs where
  model_hash_before : Nat
  dataset_commitment : Nat
  grad_norm_bound : Nat
  dp_epsilon : Nat

/-- Private training witness. -/
structure WeightWitness where
  gradients : List Nat
  noise : List Nat
  training_steps : Nat

/-- Full public input vector of the circuit. -/
structure WeightStatement where
  model_hash_before : Nat
  model_hash_after : Nat
  dataset_commitment : Nat
  grad_norm_bound : Nat
  dp_epsilon : Nat
  update_hash : Nat

/-- Proof object: carries the two derived hashes and the circuit VK binding. -/
structure WeightProof where
  model_hash_after : Nat
  update_hash : Nat
  vk_binding : Nat

/-- The compiled `WeightUpdateCircuit`'s structural description: six public
    inputs (the statement), seventeen witness components (8 gradients + 8 noise
    + training steps), and 9,569 constraints -- the last measured from the real
    compiled circuit (`results/zk/weight-proof-latest.json`). -/
def weightCircuitDescription : CircuitDescription :=
  { publicInputCount := 6, witnessArity := 17, constraintCount := 9569 }

/-- The `WeightUpdateCircuit` verification key, derived from its structural
    description. Distinct from `circuitVK` (the single-scalar
    `DataCommitmentCircuit`) and from the genesis identity key. -/
def weightCircuitVK : Nat := deriveVK weightCircuitDescription

/-- The two production circuits have distinct verification keys. -/
theorem circuitVK_ne_weightCircuitVK : circuitVK ≠ weightCircuitVK := by
  intro h
  have hdesc : dataCommitmentCircuitDescription = weightCircuitDescription :=
    deriveVK_injective h
  simp [dataCommitmentCircuitDescription, weightCircuitDescription] at hdesc

/-- Derive the full statement from the caller's inputs and the witness. Mirrors
    `internal.DeriveWeightStatement`. -/
def deriveWeightStatement (i : WeightPublicInputs) (w : WeightWitness) : WeightStatement :=
  { model_hash_before := i.model_hash_before
    model_hash_after := weightHash ([i.model_hash_before, w.training_steps] ++ w.gradients)
    dataset_commitment := i.dataset_commitment
    grad_norm_bound := i.grad_norm_bound
    dp_epsilon := i.dp_epsilon
    update_hash := weightHash ([i.dp_epsilon, w.training_steps] ++
      List.zipWith (· + ·) w.gradients w.noise ++ [i.dataset_commitment]) }

/-- The circuit relation, transcribed constraint-by-constraint from
    `internal/zkweight_circuit.go`'s `WeightUpdateCircuit.Define`:

    * `w.gradients.length = w.noise.length` — the fixed-arity vectors;
    * `ModelHashAfter = MiMC(ModelHashBefore, TrainingSteps, Gradients…)`,
      modelled by the `weightHash` surrogate fold;
    * `UpdateHash = MiMC(DPEpsilon, TrainingSteps, Gradients+Noise…,
      DatasetCommitment)`, same surrogate;
    * `DatasetCommitment ≠ 0` — the circuit's `AssertIsDifferent`;
    * `∑ Gradients[i]² ≤ GradNormBound²` — the L2 norm bound;
    * every gradient and noise component passes the circuit's 64-bit range
      check `ToBinary(component + 2^63, 64)`, i.e. `component < 2^63` in the
      model's magnitude-`Nat` encoding;
    * `GradNormBound` passes the circuit's 63-bit range check, i.e.
      `GradNormBound < 2^63`.

    The MiMC permutation itself is the `weightHash` surrogate fold, not the
    BN254 round function — see the module docstring. -/
def WeightRelation (stmt : WeightStatement) (w : WeightWitness) : Prop :=
  w.gradients.length = w.noise.length ∧
  stmt.model_hash_after = weightHash ([stmt.model_hash_before, w.training_steps] ++ w.gradients) ∧
  stmt.update_hash = weightHash ([stmt.dp_epsilon, w.training_steps] ++
    List.zipWith (· + ·) w.gradients w.noise ++ [stmt.dataset_commitment]) ∧
  stmt.dataset_commitment ≠ 0 ∧
  sumSq w.gradients ≤ stmt.grad_norm_bound * stmt.grad_norm_bound ∧
  (∀ g ∈ w.gradients, g < 2 ^ 63) ∧
  (∀ n ∈ w.noise, n < 2 ^ 63) ∧
  stmt.grad_norm_bound < 2 ^ 63

/-- Honest prover: binds the proof to the statement's derived hashes and to the
    circuit VK. Mirrors `internal.ProveWeightUpdate`. -/
def proveWeight (stmt : WeightStatement) : WeightProof :=
  ⟨stmt.model_hash_after, stmt.update_hash, weightCircuitVK⟩

/-- Verifier: accepts iff the proof carries this statement's derived hashes, the
    circuit VK, and the dataset commitment is non-zero. -/
def verifyWeight (stmt : WeightStatement) (p : WeightProof) : Bool :=
  p.model_hash_after = stmt.model_hash_after &&
  p.update_hash = stmt.update_hash &&
  p.vk_binding = weightCircuitVK &&
  stmt.dataset_commitment ≠ 0

/-- The derived statement really carries the two derived hashes. -/
theorem theorem_weight_derived_hashes (i : WeightPublicInputs) (w : WeightWitness) :
    (deriveWeightStatement i w).model_hash_after =
        weightHash ([i.model_hash_before, w.training_steps] ++ w.gradients) ∧
    (deriveWeightStatement i w).update_hash =
        weightHash ([i.dp_epsilon, w.training_steps] ++
          List.zipWith (· + ·) w.gradients w.noise ++ [i.dataset_commitment]) := by
  simp [deriveWeightStatement]

/-- An honestly derived statement satisfies the circuit relation, provided the
    dataset commitment is non-zero, the vectors have equal length, and the norm
    bound holds. -/
theorem theorem_weight_relation_of_derived (i : WeightPublicInputs) (w : WeightWitness)
    (hlen : w.gradients.length = w.noise.length)
    (hds : i.dataset_commitment ≠ 0)
    (hnorm : sumSq w.gradients ≤ i.grad_norm_bound * i.grad_norm_bound)
    (hgrad : ∀ g ∈ w.gradients, g < 2 ^ 63)
    (hnoise : ∀ n ∈ w.noise, n < 2 ^ 63)
    (hbound : i.grad_norm_bound < 2 ^ 63) :
    WeightRelation (deriveWeightStatement i w) w := by
  unfold WeightRelation deriveWeightStatement
  exact ⟨hlen, rfl, rfl, hds, hnorm, hgrad, hnoise, hbound⟩

/-- Completeness: an honestly derived statement verifies. -/
theorem theorem_weight_completeness (i : WeightPublicInputs) (w : WeightWitness)
    (hds : i.dataset_commitment ≠ 0) :
    verifyWeight (deriveWeightStatement i w) (proveWeight (deriveWeightStatement i w)) = true := by
  simp [verifyWeight, proveWeight, deriveWeightStatement, hds]

/-- Binding: an accepted proof carries the statement's hashes -- it is tied to
    the statement, not a free-floating identity as the genesis VK was. -/
theorem theorem_weight_binding (stmt : WeightStatement) (p : WeightProof)
    (h : verifyWeight stmt p = true) :
    p.model_hash_after = stmt.model_hash_after ∧ p.update_hash = stmt.update_hash := by
  unfold verifyWeight at h
  rw [Bool.and_eq_true, Bool.and_eq_true, Bool.and_eq_true] at h
  obtain ⟨⟨⟨h1, h2⟩, _⟩, _⟩ := h
  rw [decide_eq_true_eq] at h1 h2
  exact ⟨h1, h2⟩

/-- The norm bound is a real conjunct: a relation implies it. -/
theorem theorem_weight_norm_guard (stmt : WeightStatement) (w : WeightWitness)
    (h : WeightRelation stmt w) :
    sumSq w.gradients ≤ stmt.grad_norm_bound * stmt.grad_norm_bound := by
  obtain ⟨-, -, -, -, hnorm, -, -, -⟩ := h
  exact hnorm

/-- Negative control: an over-bound gradient vector does not satisfy the relation. -/
theorem theorem_weight_norm_violation_rejected (stmt : WeightStatement) (w : WeightWitness)
    (hviol : stmt.grad_norm_bound * stmt.grad_norm_bound < sumSq w.gradients) :
    ¬ WeightRelation stmt w := by
  intro hrel
  obtain ⟨-, -, -, -, hnorm, -, -, -⟩ := hrel
  omega

/-- Negative control: a zero dataset commitment does not satisfy the relation. -/
theorem theorem_weight_zero_dataset_rejected (stmt : WeightStatement) (w : WeightWitness)
    (hrel : WeightRelation stmt w) (hzero : stmt.dataset_commitment = 0) : False := by
  obtain ⟨-, -, -, hds, -, -, -, -⟩ := hrel
  exact hds hzero

/-- Negative control: mismatched gradient/noise lengths do not satisfy the relation. -/
theorem theorem_weight_length_mismatch_rejected (stmt : WeightStatement) (w : WeightWitness)
    (hmis : w.gradients.length ≠ w.noise.length) : ¬ WeightRelation stmt w := by
  intro hrel
  obtain ⟨hlen, -, -, -, -, -, -, -⟩ := hrel
  exact hmis hlen

/-- The range-check conjuncts of `WeightRelation`, projected: a relation-satisfying
    witness has every gradient and noise component inside the circuit's 64-bit
    range check and a norm bound inside its 63-bit range check. -/
theorem weight_relation_range_checks (stmt : WeightStatement) (w : WeightWitness)
    (h : WeightRelation stmt w) :
    (∀ g ∈ w.gradients, g < 2 ^ 63) ∧ (∀ n ∈ w.noise, n < 2 ^ 63) ∧
      stmt.grad_norm_bound < 2 ^ 63 := by
  obtain ⟨-, -, -, -, -, hg, hn, hb⟩ := h
  exact ⟨hg, hn, hb⟩

/-- Negative control: a gradient component outside the circuit's 64-bit range
    check does not satisfy the relation. -/
theorem theorem_weight_gradient_out_of_range_rejected (stmt : WeightStatement)
    (w : WeightWitness) (g : Nat) (hg : g ∈ w.gradients) (hbig : 2 ^ 63 ≤ g) :
    ¬ WeightRelation stmt w := by
  intro hrel
  have hlt := (weight_relation_range_checks stmt w hrel).1 g hg
  omega

/-- Negative control: a noise component outside the circuit's 64-bit range check
    does not satisfy the relation. -/
theorem theorem_weight_noise_out_of_range_rejected (stmt : WeightStatement)
    (w : WeightWitness) (n : Nat) (hn : n ∈ w.noise) (hbig : 2 ^ 63 ≤ n) :
    ¬ WeightRelation stmt w := by
  intro hrel
  have hlt := (weight_relation_range_checks stmt w hrel).2.1 n hn
  omega

/-- Negative control: a norm bound outside the circuit's 63-bit range check does
    not satisfy the relation. -/
theorem theorem_weight_norm_bound_out_of_range_rejected (stmt : WeightStatement)
    (w : WeightWitness) (hbig : 2 ^ 63 ≤ stmt.grad_norm_bound) :
    ¬ WeightRelation stmt w := by
  intro hrel
  have hlt := (weight_relation_range_checks stmt w hrel).2.2
  omega


/-- ### Negative control: what `verifyWeight` does NOT guarantee

`verifyWeight` is only a syntax/debinding check: it confirms that the proof
echoes the statement's two hashes, carries `weightCircuitVK`, and that the
statement's dataset commitment is non-zero. It never inspects `grad_norm_bound`,
the gradient or noise vectors, their lengths, or the hash-derivation equations
of `WeightRelation`. Consequently acceptance certifies none of the relation's
norm/range conjuncts: every `WeightStatement` whose `grad_norm_bound` violates
the circuit's 63-bit range check is still accepted by the honest-echo proof,
even though **no** witness can satisfy `WeightRelation` for it. This is the
precise sense in which the toy verifier is not knowledge-sound on its own --
the gap that full Groth16/q-SDH knowledge soundness would fill (module
docstring above). -/
theorem theorem_weight_acceptance_ignores_norm_bound (stmt : WeightStatement)
    (hds : stmt.dataset_commitment ≠ 0) (hbig : 2 ^ 63 ≤ stmt.grad_norm_bound) :
    verifyWeight stmt (proveWeight stmt) = true ∧ ∀ w : WeightWitness, ¬ WeightRelation stmt w := by
  constructor
  · simp [verifyWeight, proveWeight, hds]
  · intro w hrel
    have hb := (weight_relation_range_checks stmt w hrel).2.2
    omega

/-- Concrete instance of the negative control: an accepted statement/proof pair
    for which the witness relation is uninhabited. -/
theorem theorem_weight_acceptance_no_witness :
    ∃ stmt : WeightStatement, ∃ p : WeightProof,
      verifyWeight stmt p = true ∧ ∀ w : WeightWitness, ¬ WeightRelation stmt w := by
  let stmt : WeightStatement :=
    { model_hash_before := 0
      model_hash_after := 0
      dataset_commitment := 1
      grad_norm_bound := 2 ^ 63
      dp_epsilon := 0
      update_hash := 0 }
  exact ⟨stmt, proveWeight stmt,
    theorem_weight_acceptance_ignores_norm_bound stmt (by norm_num [stmt]) (by norm_num [stmt])⟩

/- ### External-soundness composition (abstract proof system)

The toy `verifyWeight` is a debinding check, not a knowledge-sound verifier:
`theorem_weight_acceptance_no_witness` exhibits an accepted statement for which
`WeightRelation` is uninhabited. Hence an external accept predicate cannot both
be sound for `WeightRelation` and agree with `verifyWeight` on *all* statements;
`theorem_weight_agreement_unrestricted_inconsistent` below refutes that
combination using the negative control. The agreement hypothesis of the
composition theorem is therefore restricted to `WeightHonestStatement`, the
image of `deriveWeightStatement` under inputs satisfying the circuit relation's
side conditions, where a witness is independently reconstructible by
`theorem_weight_relation_of_derived`. The external proof system's accept
predicate and its soundness are explicit arguments of the theorem: no axiom is
introduced, and Groth16/q-SDH knowledge soundness is not claimed to be proved
here. -/

/-- The subset of statements on which agreement between an external accept
    predicate and the toy `verifyWeight` can consistently hold: the statement is
    honestly derived from public inputs whose witness satisfies every
    non-hash conjunct of `WeightRelation`. -/
def WeightHonestStatement (stmt : WeightStatement) : Prop :=
  ∃ (i : WeightPublicInputs) (w : WeightWitness),
    stmt = deriveWeightStatement i w ∧
    w.gradients.length = w.noise.length ∧
    i.dataset_commitment ≠ 0 ∧
    sumSq w.gradients ≤ i.grad_norm_bound * i.grad_norm_bound ∧
    (∀ g ∈ w.gradients, g < 2 ^ 63) ∧
    (∀ n ∈ w.noise, n < 2 ^ 63) ∧
    i.grad_norm_bound < 2 ^ 63

/-- Every statement in the honest locus really has a `WeightRelation` witness. -/
theorem WeightHonestStatement_has_witness (stmt : WeightStatement)
    (h : WeightHonestStatement stmt) :
    ∃ w : WeightWitness, WeightRelation stmt w := by
  obtain ⟨i, w, rfl, hlen, hds, hnorm, hgrad, hnoise, hbound⟩ := h
  exact ⟨w, theorem_weight_relation_of_derived i w hlen hds hnorm hgrad hnoise hbound⟩

/-- The honest locus is nonempty, so the composition theorem has real inputs. -/
theorem WeightHonestStatement_inhabited : ∃ stmt, WeightHonestStatement stmt := by
  let i : WeightPublicInputs :=
    { model_hash_before := 0, dataset_commitment := 1, grad_norm_bound := 0, dp_epsilon := 0 }
  let w : WeightWitness := { gradients := [], noise := [], training_steps := 0 }
  refine ⟨deriveWeightStatement i w, ?_⟩
  refine ⟨i, w, rfl, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> simp [i, w, sumSq]

/-- External-soundness composition. `Accept` is any verifier predicate on
    (statement, proof) pairs and `hSound` is its soundness for `WeightRelation`,
    both supplied as ordinary arguments (not axioms). `hAgree` relates `Accept`
    to the machine-checked toy verifier only on the honest locus; outside that
    locus agreement is refutable by the negative control. From toy-verifier
    acceptance on an honest statement we obtain `Accept`, hence a witness. -/
theorem theorem_weight_external_soundness_composition
    (Accept : WeightStatement → WeightProof → Prop)
    (hSound : ∀ stmt p, Accept stmt p → ∃ w : WeightWitness, WeightRelation stmt w)
    (hAgree : ∀ stmt p, WeightHonestStatement stmt →
      (Accept stmt p ↔ verifyWeight stmt p = true))
    (stmt : WeightStatement) (p : WeightProof)
    (hHonest : WeightHonestStatement stmt)
    (hVerify : verifyWeight stmt p = true) :
    ∃ w : WeightWitness, WeightRelation stmt w := by
  exact hSound stmt p ((hAgree stmt p hHonest).2 hVerify)

/-- The agreement restriction is load-bearing: if agreement held for *every*
    statement, the existing negative control would refute soundness. -/
theorem theorem_weight_agreement_unrestricted_inconsistent
    (Accept : WeightStatement → WeightProof → Prop)
    (hSound : ∀ stmt p, Accept stmt p → ∃ w : WeightWitness, WeightRelation stmt w)
    (hAgree : ∀ stmt p, (Accept stmt p ↔ verifyWeight stmt p = true)) : False := by
  obtain ⟨stmt, p, hverify, hno⟩ := theorem_weight_acceptance_no_witness
  obtain ⟨w, hw⟩ := hSound stmt p ((hAgree stmt p).2 hverify)
  exact hno w hw

/-- The negative-control statement lies outside the honest locus. -/
theorem theorem_weight_no_witness_not_honest (stmt : WeightStatement)
    (hno : ∀ w : WeightWitness, ¬ WeightRelation stmt w) :
    ¬ WeightHonestStatement stmt := by
  intro hhon
  obtain ⟨w, hw⟩ := WeightHonestStatement_has_witness stmt hhon
  exact hno w hw

/-- Consistency of the remaining hypothesis bundle: `WeightLocusAccept` is
    globally sound and agrees with `verifyWeight` exactly on the honest locus.
    This witnesses that the residual is the agreement restriction itself, not
    an hidden contradiction in the composition theorem's assumptions. -/
def WeightLocusAccept (stmt : WeightStatement) (p : WeightProof) : Prop :=
  verifyWeight stmt p = true ∧ ∃ w : WeightWitness, WeightRelation stmt w

theorem WeightLocusAccept_sound :
    ∀ stmt p, WeightLocusAccept stmt p → ∃ w : WeightWitness, WeightRelation stmt w := by
  intro stmt p h
  exact h.2

theorem WeightLocusAccept_agrees_on_honest :
    ∀ stmt p, WeightHonestStatement stmt →
      (WeightLocusAccept stmt p ↔ verifyWeight stmt p = true) := by
  intro stmt p hhon
  constructor
  · intro h
    exact h.1
  · intro h
    exact ⟨h, WeightHonestStatement_has_witness stmt hhon⟩

theorem theorem_weight_external_soundness_composition_consistent
    (stmt : WeightStatement) (p : WeightProof)
    (hHonest : WeightHonestStatement stmt)
    (hVerify : verifyWeight stmt p = true) :
    ∃ w : WeightWitness, WeightRelation stmt w := by
  exact theorem_weight_external_soundness_composition WeightLocusAccept
    WeightLocusAccept_sound WeightLocusAccept_agrees_on_honest
    stmt p hHonest hVerify

end LeanFormalization
