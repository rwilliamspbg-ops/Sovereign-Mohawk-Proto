package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestDataCommitmentProof_Valid(t *testing.T) {
	digest := internal.DataCommitmentDigest([]byte("gradient-round-42-payload"))

	proof, commitment, err := internal.ProveDataCommitment(digest)
	if err != nil {
		t.Fatalf("ProveDataCommitment failed: %v", err)
	}

	ok, err := internal.VerifyDataCommitmentProof(proof, commitment)
	if err != nil {
		t.Fatalf("VerifyDataCommitmentProof returned unexpected error: %v", err)
	}
	if !ok {
		t.Error("expected true for a genuinely produced proof against its own commitment")
	}
}

func TestDataCommitmentProof_DifferentDataDifferentCommitment(t *testing.T) {
	digestA := internal.DataCommitmentDigest([]byte("gradient-round-1"))
	digestB := internal.DataCommitmentDigest([]byte("gradient-round-2"))

	_, commitmentA, err := internal.ProveDataCommitment(digestA)
	if err != nil {
		t.Fatalf("ProveDataCommitment(A) failed: %v", err)
	}
	_, commitmentB, err := internal.ProveDataCommitment(digestB)
	if err != nil {
		t.Fatalf("ProveDataCommitment(B) failed: %v", err)
	}

	if commitmentA.Cmp(commitmentB) == 0 {
		t.Fatal("expected different data to produce different commitments")
	}
}

func TestDataCommitmentProof_WrongCommitmentRejected(t *testing.T) {
	digestA := internal.DataCommitmentDigest([]byte("gradient-round-1"))
	digestB := internal.DataCommitmentDigest([]byte("gradient-round-2"))

	proofA, _, err := internal.ProveDataCommitment(digestA)
	if err != nil {
		t.Fatalf("ProveDataCommitment(A) failed: %v", err)
	}
	_, commitmentB, err := internal.ProveDataCommitment(digestB)
	if err != nil {
		t.Fatalf("ProveDataCommitment(B) failed: %v", err)
	}

	ok, _ := internal.VerifyDataCommitmentProof(proofA, commitmentB)
	if ok {
		t.Error("expected a proof for commitment A to be rejected against commitment B")
	}
}

func TestDataCommitmentProof_TamperedProofRejected(t *testing.T) {
	digest := internal.DataCommitmentDigest([]byte("gradient-round-tamper-check"))

	proof, commitment, err := internal.ProveDataCommitment(digest)
	if err != nil {
		t.Fatalf("ProveDataCommitment failed: %v", err)
	}
	if len(proof) == 0 {
		t.Fatal("expected non-empty serialized proof")
	}

	tampered := make([]byte, len(proof))
	copy(tampered, proof)
	tampered[len(tampered)/2] ^= 0xFF

	ok, _ := internal.VerifyDataCommitmentProof(tampered, commitment)
	if ok {
		t.Error("expected tampered proof bytes to fail verification (or fail to deserialize)")
	}
}
