package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// BenchmarkWeightProofProve measures Groth16 proving for one WeightUpdateCircuit
// statement (8 gradients). The one-time MPC trusted setup is excluded: it runs
// in the sync.Once inside ensureWeightSetup before ResetTimer.
func BenchmarkWeightProofProve(b *testing.B) {
	in, w := honestWeightFixture()
	if _, _, err := internal.ProveWeightUpdate(in, w); err != nil {
		b.Fatalf("warmup prove: %v", err)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, _, err := internal.ProveWeightUpdate(in, w); err != nil {
			b.Fatalf("prove: %v", err)
		}
	}
}

// BenchmarkWeightProofVerify measures Groth16 verification of one encoded
// WeightUpdateCircuit proof.
func BenchmarkWeightProofVerify(b *testing.B) {
	in, w := honestWeightFixture()
	encoded, _, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		b.Fatalf("prove: %v", err)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ok, err := internal.VerifyWeightProof(encoded)
		if err != nil || !ok {
			b.Fatalf("verify: ok=%v err=%v", ok, err)
		}
	}
}

// BenchmarkWeightProofSetup measures the one-time compile + MPC trusted setup.
// Run with -benchtime=1x; it is the dominant cold-start cost.
func BenchmarkWeightProofSetup(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if _, err := internal.WeightCircuitConstraintCount(); err != nil {
			b.Fatalf("setup: %v", err)
		}
	}
}
