package test

import (
	"math/big"
	"math/rand"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// Randomized counterpart to the pinned MiMC vectors in
// internal/zkweight_vectors_test.go: instead of fixed literals, generate
// witnesses and check that the off-circuit hash chain still agrees with the
// in-circuit one. ProveWeightUpdate only succeeds if DeriveWeightStatement's
// off-circuit MiMC evaluation matches the circuit's, so a verifying proof IS the
// cross-check.
func randomWeightWitness(rng *rand.Rand) (internal.WeightPublicInputs, internal.WeightWitness) {
	in := internal.WeightPublicInputs{
		ModelHashBefore:   big.NewInt(int64(rng.Intn(1 << 20))),
		DatasetCommitment: big.NewInt(int64(rng.Intn(1<<20)) + 1), // must be non-zero
		GradNormBound:     big.NewInt(1 << 40),                    // true norm^2 <= 8 * 2^40 << 2^80
		DPEpsilon:         big.NewInt(int64(rng.Intn(100))),
	}
	var w internal.WeightWitness
	for i := range w.Gradients {
		w.Gradients[i] = big.NewInt(int64(rng.Intn(1<<21) - (1 << 20)))
	}
	for i := range w.Noise {
		w.Noise[i] = big.NewInt(int64(rng.Intn(1000) - 500))
	}
	w.TrainingSteps = uint32(rng.Intn(1000))
	return in, w
}

func TestWeightProof_RandomizedWitnesses(t *testing.T) {
	skipWeightProofInRace(t)
	rng := rand.New(rand.NewSource(20261118))

	check := func(t *testing.T, name string, in internal.WeightPublicInputs, w internal.WeightWitness) {
		t.Helper()
		encoded, st, err := internal.ProveWeightUpdate(in, w)
		if err != nil {
			t.Fatalf("%s: ProveWeightUpdate: %v", name, err)
		}
		ok, err := internal.VerifyWeightProof(encoded)
		if err != nil {
			t.Fatalf("%s: VerifyWeightProof: %v", name, err)
		}
		if !ok {
			t.Fatalf("%s: proof for a randomly generated witness did not verify", name)
		}
		// The derived statement must be a pure function of (inputs, witness).
		rederived, err := internal.DeriveWeightStatement(in, w)
		if err != nil {
			t.Fatalf("%s: DeriveWeightStatement: %v", name, err)
		}
		if rederived.UpdateHash.Cmp(st.UpdateHash) != 0 || rederived.ModelHashAfter.Cmp(st.ModelHashAfter) != 0 {
			t.Fatalf("%s: derived statement is not reproducible", name)
		}
	}

	// Edge case: every gradient component zero. Exercises the fixed-point
	// encoding of 0 (whose minimal big-endian byte representation is empty, so a
	// naive `Bytes()` write would silently drop the element).
	t.Run("zero_gradients", func(t *testing.T) {
		in := internal.WeightPublicInputs{
			ModelHashBefore:   big.NewInt(1),
			DatasetCommitment: big.NewInt(2),
			GradNormBound:     big.NewInt(1 << 32),
			DPEpsilon:         big.NewInt(1),
		}
		check(t, "zero_gradients", in, internal.WeightWitness{TrainingSteps: 1})
	})

	// Edge case: a negative-only witness (all components below zero), so the
	// sign-offset range check sees its other branch.
	t.Run("all_negative", func(t *testing.T) {
		in := internal.WeightPublicInputs{
			ModelHashBefore:   big.NewInt(7),
			DatasetCommitment: big.NewInt(9),
			GradNormBound:     big.NewInt(1 << 40),
			DPEpsilon:         big.NewInt(2),
		}
		var w internal.WeightWitness
		for i := range w.Gradients {
			w.Gradients[i] = big.NewInt(-1000 - int64(i))
			w.Noise[i] = big.NewInt(-7)
		}
		w.TrainingSteps = 3
		check(t, "all_negative", in, w)
	})

	for i := 0; i < 2; i++ {
		in, w := randomWeightWitness(rng)
		check(t, "random", in, w)
	}
}
