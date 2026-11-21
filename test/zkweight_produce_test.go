package test

import (
	"context"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/zkprover"
)

// produceFixture is honestWeightFixture seen from the node side: the SDK-facing
// zkprover inputs a client actually holds. ModelHashAfter and UpdateHash are
// placeholders here because WeightUpdateCircuit DERIVES them from the witness;
// the producer must return the statement embedded in the proof, and the test
// asserts exactly that.
func produceFixture() (zkprover.PublicInputs, zkprover.PrivateInputs) {
	return zkprover.PublicInputs{
			ModelHashBefore:   "0x1234567",
			ModelHashAfter:    "0x0",
			DatasetCommitment: "0xdeadbeef",
			UpdateHash:        "0x0",
			GradNormBound:     3.0,
			DPEpsilon:         3.0,
		}, zkprover.PrivateInputs{
			Gradients:     []float64{0.5, -0.25, 1.0, -1.5, 2.0, -0.75, 0.125, -0.5},
			Noise:         []float64{0.01, -0.02, 0.03, -0.04, 0.05, -0.06, 0.07, -0.08},
			TrainingSteps: 7,
		}
}

// TestProduceWeightProof_ProductionRoundTrip closes the produce -> verify ->
// aggregate loop that ZK plan milestone M2 Gap 1 left open: the node-side
// producer feeds the aggregator's WeightProof / WeightStatement fields, which
// ProcessRound then verifies as the preferred path.
func TestProduceWeightProof_ProductionRoundTrip(t *testing.T) {
	skipWeightProofInRace(t)
	pub, priv := produceFixture()

	encoded, st, err := zkprover.ProduceWeightProof(context.Background(), zkprover.GnarkProver{}, pub, priv)
	if err != nil {
		t.Fatalf("ProduceWeightProof: %v", err)
	}
	if len(encoded) == 0 {
		t.Fatal("ProduceWeightProof returned an empty proof")
	}

	// The returned statement must be the one embedded in the proof, and the
	// proof must verify against it.
	if ok, err := internal.VerifyWeightProofAgainst(encoded, st); err != nil || !ok {
		t.Fatalf("VerifyWeightProofAgainst(produced) = %v, %v; want true, nil", ok, err)
	}

	// ModelHashAfter / UpdateHash are derived by the circuit, so the producer's
	// statement must carry the derived values, not the caller's placeholders.
	// Rebuild the circuit's public inputs from the SDK-facing ones (DPEpsilon is
	// Q32.32 fixed-point, so it must go through EncodeFixedPoint to match).
	mb, err := internal.ParseCommitmentHex(pub.ModelHashBefore)
	if err != nil {
		t.Fatalf("ParseCommitmentHex(model): %v", err)
	}
	dc, err := internal.ParseCommitmentHex(pub.DatasetCommitment)
	if err != nil {
		t.Fatalf("ParseCommitmentHex(dataset): %v", err)
	}
	gb, err := internal.EncodeFixedPoint(pub.GradNormBound)
	if err != nil {
		t.Fatalf("EncodeFixedPoint(norm): %v", err)
	}
	de, err := internal.EncodeFixedPoint(pub.DPEpsilon)
	if err != nil {
		t.Fatalf("EncodeFixedPoint(epsilon): %v", err)
	}
	_, w := honestWeightFixture()
	want, err := internal.DeriveWeightStatement(internal.WeightPublicInputs{
		ModelHashBefore:   mb,
		DatasetCommitment: dc,
		GradNormBound:     gb,
		DPEpsilon:         de,
	}, w)
	if err != nil {
		t.Fatalf("DeriveWeightStatement: %v", err)
	}
	if st.ModelHashAfter.Cmp(want.ModelHashAfter) != 0 {
		t.Fatalf("ModelHashAfter = %v, want the derived %v", st.ModelHashAfter, want.ModelHashAfter)
	}
	if st.UpdateHash.Cmp(want.UpdateHash) != 0 {
		t.Fatalf("UpdateHash = %v, want the derived %v", st.UpdateHash, want.UpdateHash)
	}

	agg := batch.NewAggregator(weightAggregatorConfig())
	agg.WeightProof = encoded
	agg.WeightStatement = &st
	if err := agg.ProcessRound(batch.ModeHonest); err != nil {
		t.Fatalf("ProcessRound with produced weight proof: %v", err)
	}
	if !agg.Verified {
		t.Fatal("expected Verified=true after successful weight attestation")
	}
}

// TestProduceWeightProof_RejectsPlaceholderProver checks the Gap-2 guard: a
// MockProver "proof" is not a WeightUpdateCircuit proof, so the producer must
// refuse to emit it instead of passing it to the aggregator.
func TestProduceWeightProof_RejectsPlaceholderProver(t *testing.T) {
	pub, priv := produceFixture()
	if _, _, err := zkprover.ProduceWeightProof(context.Background(), zkprover.MockProver{}, pub, priv); err == nil {
		t.Fatal("expected ProduceWeightProof to reject MockProver's placeholder proof")
	}
}

// TestProduceWeightProof_RejectsNilProver checks the nil-prover guard.
func TestProduceWeightProof_RejectsNilProver(t *testing.T) {
	pub, priv := produceFixture()
	if _, _, err := zkprover.ProduceWeightProof(context.Background(), nil, pub, priv); err == nil {
		t.Fatal("expected ProduceWeightProof to reject a nil prover")
	}
}

// TestProduceWeightProof_TamperedProofFailsVerification is the negative control
// on the verification step the producer relies on: flipping a byte must break it.
func TestProduceWeightProof_TamperedProofFailsVerification(t *testing.T) {
	skipWeightProofInRace(t)
	pub, priv := produceFixture()
	encoded, st, err := zkprover.ProduceWeightProof(context.Background(), zkprover.GnarkProver{}, pub, priv)
	if err != nil {
		t.Fatalf("ProduceWeightProof: %v", err)
	}
	tampered := append([]byte(nil), encoded...)
	tampered[len(tampered)-1] ^= 0xFF
	// A tampered proof must not verify. It may fail verification or fail to
	// deserialize; either way it must not come back as a valid proof.
	if ok, err := internal.VerifyWeightProofAgainst(tampered, st); err == nil && ok {
		t.Fatalf("VerifyWeightProofAgainst(tampered) = true, nil; want it rejected")
	}
}
