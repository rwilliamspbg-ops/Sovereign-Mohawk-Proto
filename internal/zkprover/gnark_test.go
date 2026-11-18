package zkprover

import (
	"context"
	"encoding/hex"
	"math/big"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func testGradients() []float64 {
	return []float64{0.5, -0.25, 1.0, -1.5, 2.0, -0.75, 0.125, -0.5}
}

func testNoise() []float64 {
	return []float64{0.01, -0.02, 0.03, -0.04, 0.05, -0.06, 0.07, -0.08}
}

func hexOf(v *big.Int) string {
	if v == nil {
		return ""
	}
	return "0x" + hex.EncodeToString(v.Bytes())
}

// derivePub fills in the two derived public hashes so the caller's statement
// matches what Prove will assert.
func derivePub(t *testing.T, pub PublicInputs, priv PrivateInputs) PublicInputs {
	t.Helper()
	var w internal.WeightWitness
	for i, g := range priv.Gradients {
		gf, err := internal.EncodeFixedPoint(g)
		if err != nil {
			t.Fatalf("gradient %d: %v", i, err)
		}
		w.Gradients[i] = gf
	}
	for i, n := range priv.Noise {
		nf, err := internal.EncodeFixedPoint(n)
		if err != nil {
			t.Fatalf("noise %d: %v", i, err)
		}
		w.Noise[i] = nf
	}
	w.TrainingSteps = priv.TrainingSteps

	mb, _ := internal.ParseCommitmentHex(pub.ModelHashBefore)
	ds, _ := internal.ParseCommitmentHex(pub.DatasetCommitment)
	bound, err := internal.EncodeFixedPoint(pub.GradNormBound)
	if err != nil {
		t.Fatalf("bound: %v", err)
	}
	eps, err := internal.EncodeFixedPoint(pub.DPEpsilon)
	if err != nil {
		t.Fatalf("epsilon: %v", err)
	}
	st, err := internal.DeriveWeightStatement(internal.WeightPublicInputs{
		ModelHashBefore:   mb,
		DatasetCommitment: ds,
		GradNormBound:     bound,
		DPEpsilon:         eps,
	}, w)
	if err != nil {
		t.Fatalf("derive: %v", err)
	}
	pub.ModelHashAfter = hexOf(st.ModelHashAfter)
	pub.UpdateHash = hexOf(st.UpdateHash)
	return pub
}

func TestGnarkProverRoundTrip(t *testing.T) {
	p := GnarkProver{}
	ctx := context.Background()
	priv := PrivateInputs{Gradients: testGradients(), Noise: testNoise(), TrainingSteps: 5}
	pub := derivePub(t, PublicInputs{
		ModelHashBefore:   "0x1234",
		DatasetCommitment: "0xbeef",
		GradNormBound:     3.0,
		DPEpsilon:         1.0,
	}, priv)

	proof, err := p.Prove(ctx, pub, priv)
	if err != nil {
		t.Fatal(err)
	}
	ok, err := p.Verify(ctx, pub, proof)
	if err != nil || !ok {
		t.Fatalf("verify failed: %v %v", err, ok)
	}
}

func TestGnarkProverVerifyRejectsWrongStatement(t *testing.T) {
	p := GnarkProver{}
	ctx := context.Background()
	priv := PrivateInputs{Gradients: testGradients(), Noise: testNoise(), TrainingSteps: 5}
	pub := derivePub(t, PublicInputs{
		ModelHashBefore:   "0x1234",
		DatasetCommitment: "0xbeef",
		GradNormBound:     3.0,
		DPEpsilon:         1.0,
	}, priv)

	proof, err := p.Prove(ctx, pub, priv)
	if err != nil {
		t.Fatal(err)
	}

	wrong := pub
	wrong.UpdateHash = "0xdead"
	ok, err := p.Verify(ctx, wrong, proof)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ok {
		t.Fatal("proof verified against a statement the caller did not claim")
	}
}

func TestGnarkProverRequiresCircuitArity(t *testing.T) {
	p := GnarkProver{}
	ctx := context.Background()
	priv := PrivateInputs{Gradients: []float64{1, 2, 3}, Noise: []float64{0.1, 0.1, 0.1}, TrainingSteps: 5}
	pub := PublicInputs{ModelHashBefore: "0x1", ModelHashAfter: "0x2", DatasetCommitment: "0x3", UpdateHash: "0x4", GradNormBound: 10, DPEpsilon: 1}
	if _, err := p.Prove(ctx, pub, priv); err == nil {
		t.Fatal("expected an arity error for 3 gradients")
	}
}

func TestGnarkProverRequiresStatement(t *testing.T) {
	p := GnarkProver{}
	ctx := context.Background()
	priv := PrivateInputs{Gradients: testGradients(), Noise: testNoise(), TrainingSteps: 5}
	pub := PublicInputs{GradNormBound: 3.0, DPEpsilon: 1.0}
	if _, err := p.Prove(ctx, pub, priv); err == nil {
		t.Fatal("expected an error for a missing public statement")
	}
}

func TestGnarkProverAvailable(t *testing.T) {
	if !(GnarkProver{}).Available(context.Background()) {
		t.Fatal("expected available")
	}
}
