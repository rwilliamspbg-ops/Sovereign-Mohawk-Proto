# ZK Weight-Update Circuit (Pillar 1)

## Status
Compilable Noir 1.0 circuit with CI (`nargo compile` + `nargo test`). Target backend: **Noir** (transparent setup, no trusted ceremony).

## Public inputs
- `model_hash_before: Field` — hash of the model before training.
- `model_hash_after: Field` — hash of the model after training.
- `dataset_commitment: Field` — Merkle root of the local training batch.
- `grad_norm_bound: Field` — maximum allowed L2 norm of the gradient.
- `dp_epsilon: Field`, `dp_delta: Field` — differential-privacy budget.
- `update_hash: Field` — hash of the compressed update sent to the aggregator.

## Private inputs
- `gradients: [Field; N]` — the computed gradient vector.
- `noise: [Field; N]` — DP noise added before compression.
- `training_steps: u32` — number of local SGD steps.

## Constraints
1. **Training occurred**: `model_hash_after == hash(model_hash_before, gradients, training_steps)`.
2. **Norm bound**: `sum(gradients[i]^2) <= grad_norm_bound^2`.
3. **DP noise**: `noise` is drawn from a calibrated distribution (verified via a
   range proof or a committed randomness seed); `noisy_grad = gradients + noise`.
4. **Compression fidelity**: `update_hash == hash(compress(noisy_grad))`.
5. **Dataset binding**: `dataset_commitment` is a Merkle root over the batch
   indices used; the circuit checks the batch is non-empty.

## Verification
The aggregator verifies the proof in O(1) pairing time (Groth16) or O(log n)
(STARK/Halo2). A missing or invalid proof causes the update to be rejected
(fail-closed).

## Open items
- Choose between Noir and Halo2 (decision point in GOLD_STANDARD_PLAN.md §8).
- Determine proving time budget for transformer-scale models.
- Wire prover into the Go node-agent (cgo or sidecar).
- Formal link: extend `proofs/ZKSnarkVerification.lean`.
