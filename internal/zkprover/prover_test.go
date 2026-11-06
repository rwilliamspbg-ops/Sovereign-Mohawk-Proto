package zkprover

import (
	"context"
	"testing"
)

func TestMockProverRoundTrip(t *testing.T) {
	p := MockProver{}
	ctx := context.Background()
	pub := PublicInputs{
		ModelHashBefore: "abc", ModelHashAfter: "def", UpdateHash: "ghi",
		GradNormBound: 10,
	}
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

func TestMockProverNormViolation(t *testing.T) {
	p := MockProver{}
	ctx := context.Background()
	pub := PublicInputs{GradNormBound: 1}
	priv := PrivateInputs{Gradients: []float64{10, 10, 10}, Noise: []float64{0, 0, 0}}
	if _, err := p.Prove(ctx, pub, priv); err == nil {
		t.Fatal("expected norm violation error")
	}
}

func TestMockProverLengthMismatch(t *testing.T) {
	p := MockProver{}
	ctx := context.Background()
	pub := PublicInputs{GradNormBound: 10}
	priv := PrivateInputs{Gradients: []float64{1, 2}, Noise: []float64{0.1}}
	if _, err := p.Prove(ctx, pub, priv); err == nil {
		t.Fatal("expected length mismatch error")
	}
}

func TestSelectProver(t *testing.T) {
	ctx := context.Background()
	if _, err := SelectProver(ctx, nil); err != ErrUnavailable {
		t.Fatalf("expected ErrUnavailable, got %v", err)
	}
	p, err := SelectProver(ctx, []Prover{MockProver{}})
	if err != nil || p == nil {
		t.Fatalf("select failed: %v", err)
	}
	if p.Name() != "mock" {
		t.Fatalf("unexpected name: %s", p.Name())
	}
}

func TestCLIProverAvailability(t *testing.T) {
	c := CLIProver{Binary: "definitely-not-a-binary-xyz"}
	if c.Available(context.Background()) {
		t.Fatal("expected unavailable")
	}
}
