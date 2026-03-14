package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

func TestVerifyShardIntegrity_Valid(t *testing.T) {
	// 23 participants, 10 faulty -> 13 honest, which satisfies the 55.5% boundary.
	if err := tpm.VerifyShardIntegrity(23, 10); err != nil {
		t.Fatalf("Expected shard integrity to pass, got: %v", err)
	}
}

func TestVerifyShardIntegrity_Violated(t *testing.T) {
	// 5 participants, 3 faulty → 5 <= 2*3 = 6 → fails
	if err := tpm.VerifyShardIntegrity(5, 3); err == nil {
		t.Fatal("Expected shard integrity violation, got nil")
	}
}

func TestVerifyShardIntegrity_BoundaryExact(t *testing.T) {
	// Boundary: n == 2f → should fail (must be strictly greater)
	if err := tpm.VerifyShardIntegrity(10, 5); err == nil {
		t.Fatal("Expected failure when n == 2f, got nil")
	}
}
