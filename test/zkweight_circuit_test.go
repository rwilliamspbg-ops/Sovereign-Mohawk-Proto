package test

import (
	"math/big"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// honestWeightFixture builds a satisfiable update: 8 gradients with a known L2
// norm, unit noise, and a dataset commitment.
func honestWeightFixture() (internal.WeightPublicInputs, internal.WeightWitness) {
	in := internal.WeightPublicInputs{
		ModelHashBefore:   big.NewInt(0x1234567),
		DatasetCommitment: big.NewInt(0xdeadbeef),
		DPEpsilon:         big.NewInt(3),
	}

	gradients := []float64{0.5, -0.25, 1.0, -1.5, 2.0, -0.75, 0.125, -0.5}
	noise := []float64{0.01, -0.02, 0.03, -0.04, 0.05, -0.06, 0.07, -0.08}

	var w internal.WeightWitness
	for i, g := range gradients {
		gf, err := internal.EncodeFixedPoint(g)
		if err != nil {
			panic(err)
		}
		w.Gradients[i] = gf
	}
	for i, n := range noise {
		nf, err := internal.EncodeFixedPoint(n)
		if err != nil {
			panic(err)
		}
		w.Noise[i] = nf
	}
	w.TrainingSteps = 7

	// Bound: true norm^2 in Q32.32 is sum(g^2)*2^64; use a generous bound.
	// sum(g^2) = 0.25+0.0625+1+2.25+4+0.5625+0.015625+0.25 = 8.390625
	bound, err := internal.EncodeFixedPoint(3.0) // 9 >= 8.390625
	if err != nil {
		panic(err)
	}
	in.GradNormBound = bound
	return in, w
}

func TestWeightProof_HonestRoundTrips(t *testing.T) {
	in, w := honestWeightFixture()
	encoded, st, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("ProveWeightUpdate: %v", err)
	}
	if len(encoded) == 0 {
		t.Fatal("empty encoded proof")
	}

	ok, err := internal.VerifyWeightProof(encoded)
	if err != nil {
		t.Fatalf("VerifyWeightProof: %v", err)
	}
	if !ok {
		t.Fatal("honest update did not verify")
	}

	// The derived statement must be reproducible off-circuit.
	rederived, err := internal.DeriveWeightStatement(in, w)
	if err != nil {
		t.Fatalf("DeriveWeightStatement: %v", err)
	}
	if rederived.UpdateHash.Cmp(st.UpdateHash) != 0 || rederived.ModelHashAfter.Cmp(st.ModelHashAfter) != 0 {
		t.Fatal("derived statement is not deterministic")
	}
}

func TestWeightProof_DifferentGradientsDifferentStatement(t *testing.T) {
	in, w := honestWeightFixture()
	_, stA, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("prove A: %v", err)
	}

	w2 := w
	g, err := internal.EncodeFixedPoint(0.75)
	if err != nil {
		t.Fatal(err)
	}
	w2.Gradients[0] = g
	_, stB, err := internal.ProveWeightUpdate(in, w2)
	if err != nil {
		t.Fatalf("prove B: %v", err)
	}

	if stA.UpdateHash.Cmp(stB.UpdateHash) == 0 {
		t.Fatal("distinct gradient vectors produced the same update hash")
	}
	if stA.ModelHashAfter.Cmp(stB.ModelHashAfter) == 0 {
		t.Fatal("distinct gradient vectors produced the same model hash")
	}
}

func TestWeightProof_TamperedStatementRejected(t *testing.T) {
	in, w := honestWeightFixture()
	encoded, st, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("prove: %v", err)
	}

	tampered := st
	tampered.UpdateHash = new(big.Int).Add(st.UpdateHash, big.NewInt(1))
	reencoded, err := internal.EncodeWeightProof(mustDecodeRaw(t, encoded), tampered)
	if err != nil {
		t.Fatalf("re-encode: %v", err)
	}
	ok, err := internal.VerifyWeightProof(reencoded)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if ok {
		t.Fatal("proof verified against a tampered public statement")
	}
}

func TestWeightProof_OverBoundRejected(t *testing.T) {
	in, w := honestWeightFixture()
	encoded, st, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("prove: %v", err)
	}

	// Shrink the norm bound below the true norm: the statement no longer holds.
	small, err := internal.EncodeFixedPoint(1.0) // 1 < 8.39
	if err != nil {
		t.Fatal(err)
	}
	tampered := st
	tampered.GradNormBound = small
	reencoded, err := internal.EncodeWeightProof(mustDecodeRaw(t, encoded), tampered)
	if err != nil {
		t.Fatalf("re-encode: %v", err)
	}
	ok, err := internal.VerifyWeightProof(reencoded)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if ok {
		t.Fatal("over-bound update verified")
	}
}

func TestWeightProof_ZeroDatasetCommitmentUnsatisfiable(t *testing.T) {
	in, w := honestWeightFixture()
	in.DatasetCommitment = big.NewInt(0)
	if _, _, err := internal.ProveWeightUpdate(in, w); err == nil {
		t.Fatal("expected proving to fail for a zero dataset commitment")
	}
}

func TestWeightProof_TamperedProofRejected(t *testing.T) {
	in, w := honestWeightFixture()
	encoded, _, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("prove: %v", err)
	}
	tampered := make([]byte, len(encoded))
	copy(tampered, encoded)
	tampered[len(tampered)-1] ^= 0xFF

	// A corrupted proof must never be accepted. Deserialization failure is an
	// error (the bytes are not a proof at all); a well-formed but invalid proof
	// is (false, nil). Both are rejections.
	ok, err := internal.VerifyWeightProof(tampered)
	if err == nil && ok {
		t.Fatal("tampered proof verified")
	}
}

func TestWeightProof_ConstraintCountReported(t *testing.T) {
	n, err := internal.WeightCircuitConstraintCount()
	if err != nil {
		t.Fatalf("WeightCircuitConstraintCount: %v", err)
	}
	if n <= 0 {
		t.Fatalf("non-positive constraint count %d", n)
	}
	t.Logf("WeightUpdateCircuit constraints: %d", n)
}

func mustDecodeRaw(t *testing.T, encoded []byte) []byte {
	t.Helper()
	raw, _, err := internal.DecodeWeightProof(encoded)
	if err != nil {
		t.Fatalf("DecodeWeightProof: %v", err)
	}
	return raw
}
