package test

import (
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

// TestBatchAggregator_ZKCircuitAttestation verifies that when a gradient
// commitment is supplied, ProcessRound validates the round's proof via the
// MiMC data-commitment circuit verifier (real Groth16 over a compiled R1CS)
// rather than the legacy SHA-256-of-empty baseline check.
func TestBatchAggregator_ZKCircuitAttestation(t *testing.T) {
	cfg := &batch.Config{
		TotalNodes:       1000,
		HonestNodes:      900,
		MaliciousNodes:   100,
		RedundancyFactor: 10,
	}
	agg := batch.NewAggregator(cfg)

	// Honest gradient payload -> commitment + proof.
	preimage := internalpkg.DataCommitmentDigest([]byte("gradient-round-zk-test"))
	proof, commitment, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	agg.GradientCommitment = commitment
	agg.GradientProof = proof

	if err := agg.ProcessRound(batch.ModeHonest); err != nil {
		t.Fatalf("ProcessRound with valid ZK proof: %v", err)
	}
	if !agg.Verified {
		t.Fatal("expected Verified=true after successful ZK attestation")
	}

	// Tampered proof must be rejected.
	tampered := make([]byte, len(proof))
	copy(tampered, proof)
	if len(tampered) > 0 {
		tampered[len(tampered)/2] ^= 0xFF
	}
	agg2 := batch.NewAggregator(cfg)
	agg2.GradientCommitment = commitment
	agg2.GradientProof = tampered
	if err := agg2.ProcessRound(batch.ModeHonest); err == nil {
		t.Fatal("expected tampered proof to be rejected")
	}

	// Wrong commitment must be rejected.
	otherPreimage := internalpkg.DataCommitmentDigest([]byte("other-gradient"))
	_, otherCommitment, err := internalpkg.ProveDataCommitment(otherPreimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment(other): %v", err)
	}
	agg3 := batch.NewAggregator(cfg)
	agg3.GradientCommitment = otherCommitment
	agg3.GradientProof = proof // proof for original commitment
	if err := agg3.ProcessRound(batch.ModeHonest); err == nil {
		t.Fatal("expected proof/commitment mismatch to be rejected")
	}

}