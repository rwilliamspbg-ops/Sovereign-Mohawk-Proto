package zkprover

import (
	"context"
	"testing"
)

func TestGnarkProverRoundTrip(t *testing.T) {
	p := GnarkProver{}
	ctx := context.Background()
	pub := PublicInputs{ModelHashBefore: "a", ModelHashAfter: "b", UpdateHash: "c", GradNormBound: 10}
	priv := PrivateInputs{Gradients: []float64{1, 2, 3}, Noise: []float64{0.1, 0.1, 0.1}, TrainingSteps: 5}
	proof, err := p.Prove(ctx, pub, priv)
	if err != nil {
		t.Fatal(err)
	}
	ok, err := p.Verify(ctx, pub, proof)
	if err != nil || !ok {
		t.Fatalf("verify failed: %v %v", err, ok)
	}
}

func TestGnarkProverAvailable(t *testing.T) {
	if !(GnarkProver{}).Available(context.Background()) {
		t.Fatal("expected available")
	}
}