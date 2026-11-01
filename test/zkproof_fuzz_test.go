package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/proofs"
)

func FuzzVerifyZKProof(f *testing.F) {
	f.Add("abc123", []byte("proof"), make([]byte, 32))
	f.Fuzz(func(t *testing.T, expectedRoot string, proofData []byte, salt []byte) {
		if len(salt) != 32 {
			t.Skip()
		}
		var s [32]byte
		copy(s[:], salt)
		r1, _ := proofs.VerifyHashCommitment(expectedRoot, proofData, s)
		r2, _ := proofs.VerifyHashCommitment(expectedRoot, proofData, s)
		if r1 != r2 {
			t.Fatalf("non-deterministic result: %v vs %v", r1, r2)
		}
	})
}
