// Noir circuit for the per-update ZK proof (Pillar 1, P1.1).
// Compiles with Noir 1.0.0.

use std::hash::pedersen_hash;

fn main(
    // Public inputs
    model_hash_before: pub Field,
    model_hash_after: pub Field,
    dataset_commitment: pub Field,
    grad_norm_bound: pub Field,
    dp_epsilon: pub Field,
    update_hash: pub Field,
    // Private inputs
    gradients: [Field; 8],
    noise: [Field; 8],
    training_steps: u32,
) {
    // 1. Training occurred: bind model_hash_after to a hash chain.
    let mut recomputed = pedersen_hash([model_hash_before, training_steps as Field]);
    for i in 0..8 {
        recomputed = pedersen_hash([recomputed, gradients[i]]);
    }
    assert(recomputed == model_hash_after);

    // 2. Norm bound: range-check to 64 bits and compare in u128.
    let bound_u128: u128 = grad_norm_bound as u128;
    assert((bound_u128 as Field) == grad_norm_bound);
    assert(bound_u128 < (1_u128 << 64));

    let mut norm_sq_u128: u128 = 0;
    for i in 0..8 {
        let g_u128: u128 = gradients[i] as u128;
        assert((g_u128 as Field) == gradients[i]);
        assert(g_u128 < (1_u128 << 64));
        norm_sq_u128 = norm_sq_u128 + g_u128 * g_u128;
    }
    assert(norm_sq_u128 <= bound_u128 * bound_u128);

    // 3. Update hash binding: hash over noised update and DP/training metadata.
    let mut recomputed_update = pedersen_hash([dp_epsilon, training_steps as Field]);
    for i in 0..8 {
        let noised_grad = gradients[i] + noise[i];
        recomputed_update = pedersen_hash([recomputed_update, noised_grad]);
    }
    recomputed_update = pedersen_hash([recomputed_update, dataset_commitment]);
    assert(recomputed_update == update_hash);

    // 4. Dataset binding: non-empty commitment.
    assert(dataset_commitment != 0);
}

#[test]
fn test_basic() {
    let model_hash_before: Field = 1;
    let training_steps: u32 = 10;
    let gradients: [Field; 8] = [1, 2, 3, 4, 5, 6, 7, 8];
    let noise: [Field; 8] = [1, 1, 1, 1, 1, 1, 1, 1];
    let dp_epsilon: Field = 5;
    let dataset_commitment: Field = 3;
    let grad_norm_bound: Field = 20;

    // Compute expected model_hash_after.
    let mut mh = pedersen_hash([model_hash_before, training_steps as Field]);
    for i in 0..8 {
        mh = pedersen_hash([mh, gradients[i]]);
    }

    // Compute expected update_hash.
    let mut uh = pedersen_hash([dp_epsilon, training_steps as Field]);
    for i in 0..8 {
        let noised = gradients[i] + noise[i];
        uh = pedersen_hash([uh, noised]);
    }
    uh = pedersen_hash([uh, dataset_commitment]);

    main(
        model_hash_before,
        mh,
        dataset_commitment,
        grad_norm_bound,
        dp_epsilon,
        uh,
        gradients,
        noise,
        training_steps,
    );
}