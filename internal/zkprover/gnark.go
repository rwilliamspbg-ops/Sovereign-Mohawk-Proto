package zkprover

import (
	"context"
	"fmt"
	"math"
	"math/big"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// GnarkProver is a real Groth16 prover backed by gnark/BN254.
// It proves knowledge of a MiMC preimage of the supplied data commitment,
// binding the proof to the update payload rather than a fixed identity.
type GnarkProver struct{}

func (GnarkProver) Name() string { return "gnark-groth16" }

func (GnarkProver) Available(_ context.Context) bool { return true }

func (GnarkProver) Prove(_ context.Context, pub PublicInputs, priv PrivateInputs) (Proof, error) {
	if len(priv.Gradients) == 0 {
		return Proof{}, fmt.Errorf("zkprover: empty gradients")
	}
	if len(priv.Gradients) != len(priv.Noise) {
		return Proof{}, fmt.Errorf("zkprover: gradient/noise length mismatch")
	}

	// Bind proof to the update payload by hashing the gradients (as float64
	// bits) into a single preimage field element.
	preimage := big.NewInt(0)
	for i, g := range priv.Gradients {
		bits := math.Float64bits(g)
		preimage.Xor(preimage, new(big.Int).SetUint64(bits<<uint(i%64)))
	}
	// Mix in noise and training steps.
	for i, n := range priv.Noise {
		bits := math.Float64bits(n)
		preimage.Xor(preimage, new(big.Int).SetUint64(bits<<uint((i+1)%64)))
	}
	preimage.Xor(preimage, big.NewInt(int64(priv.TrainingSteps)))

	proofBytes, commitment, err := internal.ProveDataCommitment(preimage)
	if err != nil {
		return Proof{}, fmt.Errorf("zkprover: prove failed: %w", err)
	}

	// Store commitment in the proof bytes? We return proof bytes only; caller
	// must retain commitment. Encode commitment as trailing 32 bytes for
	// convenience.
	out := make([]byte, len(proofBytes)+32)
	copy(out, proofBytes)
	cb := commitment.Bytes()
	copy(out[len(proofBytes):], cb)

	return Proof{Bytes: out, Backend: "gnark-groth16"}, nil
}

func (GnarkProver) Verify(_ context.Context, pub PublicInputs, proof Proof) (bool, error) {
	if proof.Backend != "gnark-groth16" {
		return false, fmt.Errorf("zkprover: backend mismatch")
	}
	if len(proof.Bytes) < 32 {
		return false, fmt.Errorf("zkprover: proof too short")
	}
	proofBytes := proof.Bytes[:len(proof.Bytes)-32]
	commitmentBytes := proof.Bytes[len(proof.Bytes)-32:]
	commitment := new(big.Int).SetBytes(commitmentBytes)

	ok, err := internal.VerifyDataCommitmentProof(proofBytes, commitment)
	if err != nil {
		return false, err
	}
	return ok, nil
}