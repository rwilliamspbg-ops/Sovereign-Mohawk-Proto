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
		_, _ = proofs.VerifyZKProof(expectedRoot, proofData, s)
	})
}
