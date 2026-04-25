package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/computeproof"
)

func TestComputeProofVerifyAndReplayProtection(t *testing.T) {
	trace := computeproof.Trace{
		RoundID:               "r-10",
		TaskHash:              "task-hash-abc",
		NodeID:                "node-1",
		StepCount:             32,
		DatasetCommitment:     "dataset-commit",
		ModelCommitmentBefore: "model-before",
		ModelCommitmentAfter:  "model-after",
	}
	proof, err := computeproof.BuildProof(trace, "challenge-1")
	if err != nil {
		t.Fatalf("build proof: %v", err)
	}
	v := computeproof.NewVerifier()
	ok, err := v.Verify(trace, proof)
	if err != nil || !ok {
		t.Fatalf("expected first verification success, ok=%v err=%v", ok, err)
	}
	ok, err = v.Verify(trace, proof)
	if err != nil {
		t.Fatalf("unexpected replay verification error: %v", err)
	}
	if ok {
		t.Fatal("expected replayed proof to be rejected")
	}
}

func TestComputeProofInvalidSealRejected(t *testing.T) {
	trace := computeproof.Trace{
		RoundID:               "r-11",
		TaskHash:              "task-hash-def",
		NodeID:                "node-2",
		StepCount:             10,
		DatasetCommitment:     "d",
		ModelCommitmentBefore: "b",
		ModelCommitmentAfter:  "a",
	}
	proof, err := computeproof.BuildProof(trace, "challenge-2")
	if err != nil {
		t.Fatalf("build proof: %v", err)
	}
	proof.Seal = "00bad"
	ok, err := computeproof.NewVerifier().Verify(trace, proof)
	if err != nil {
		t.Fatalf("unexpected verification error: %v", err)
	}
	if ok {
		t.Fatal("expected invalid seal to fail verification")
	}
}
