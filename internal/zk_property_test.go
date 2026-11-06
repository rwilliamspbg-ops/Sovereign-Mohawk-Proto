package internal

import (
	"math/big"
	"math/rand/v2"
	"testing"
)

// Property-based regression net for Refinement/ZKCircuit.lean.
// Soundness: an honestly generated proof verifies. Binding: a proof verifies
// only against its own commitment (tampered commitment rejected).

func TestZK_Property_HonestProofVerifies(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 0))
	const trials = 5
	for trial := 0; trial < trials; trial++ {
		preimage := new(big.Int).SetUint64(rng.Uint64())
		proofBytes, commitment, err := ProveDataCommitment(preimage)
		if err != nil {
			t.Fatalf("trial %d: prove: %v", trial, err)
		}
		ok, err := VerifyDataCommitmentProof(proofBytes, commitment)
		if err != nil {
			t.Fatalf("trial %d: verify err: %v", trial, err)
		}
		if !ok {
			t.Fatalf("trial %d: honest proof rejected", trial)
		}
	}
}

func TestZK_Property_TamperedCommitmentRejected(t *testing.T) {
	rng := rand.New(rand.NewPCG(2, 0))
	const trials = 5
	for trial := 0; trial < trials; trial++ {
		preimage := new(big.Int).SetUint64(rng.Uint64())
		proofBytes, commitment, err := ProveDataCommitment(preimage)
		if err != nil {
			t.Fatalf("trial %d: prove: %v", trial, err)
		}
		// tamper commitment
		tampered := new(big.Int).Add(commitment, big.NewInt(1))
		ok, err := VerifyDataCommitmentProof(proofBytes, tampered)
		if err != nil {
			// deserialization/other errors are acceptable rejections
			continue
		}
		if ok {
			t.Fatalf("trial %d: tampered commitment accepted", trial)
		}
	}
}

func TestZK_Property_TamperedProofRejected(t *testing.T) {
	rng := rand.New(rand.NewPCG(3, 0))
	const trials = 3
	for trial := 0; trial < trials; trial++ {
		preimage := new(big.Int).SetUint64(rng.Uint64())
		proofBytes, commitment, err := ProveDataCommitment(preimage)
		if err != nil {
			t.Fatalf("trial %d: prove: %v", trial, err)
		}
		// flip a byte in the proof
		if len(proofBytes) > 0 {
			proofBytes[0] ^= 0xFF
		}
		ok, err := VerifyDataCommitmentProof(proofBytes, commitment)
		if err == nil && ok {
			t.Fatalf("trial %d: tampered proof accepted", trial)
		}
	}
}