package zkprover

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

// MockProver is a deterministic in-process prover used for tests and CI.
// It does not generate a real SNARK; it produces a hash-based placeholder
// proof and validates structural constraints only.
type MockProver struct{}

func (MockProver) Name() string { return "mock" }

func (MockProver) Available(_ context.Context) bool { return true }

func (MockProver) Prove(_ context.Context, pub PublicInputs, priv PrivateInputs) (Proof, error) {
	if len(priv.Gradients) == 0 {
		return Proof{}, fmt.Errorf("zkprover: empty gradients")
	}
	if len(priv.Gradients) != len(priv.Noise) {
		return Proof{}, fmt.Errorf("zkprover: gradient/noise length mismatch")
	}
	// norm check
	normSq := 0.0
	for _, g := range priv.Gradients {
		normSq += g * g
	}
	if normSq > pub.GradNormBound*pub.GradNormBound && pub.GradNormBound > 0 {
		return Proof{}, fmt.Errorf("zkprover: gradient norm exceeds bound")
	}
	h := sha256.Sum256([]byte(pub.ModelHashBefore + pub.ModelHashAfter + pub.UpdateHash))
	return Proof{Bytes: h[:], Backend: "mock"}, nil
}

func (MockProver) Verify(_ context.Context, pub PublicInputs, proof Proof) (bool, error) {
	if proof.Backend != "mock" {
		return false, fmt.Errorf("zkprover: backend mismatch")
	}
	h := sha256.Sum256([]byte(pub.ModelHashBefore + pub.ModelHashAfter + pub.UpdateHash))
	return hex.EncodeToString(h[:]) == hex.EncodeToString(proof.Bytes), nil
}
