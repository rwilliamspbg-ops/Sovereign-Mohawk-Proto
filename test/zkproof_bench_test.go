package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/proofs"
)

func BenchmarkVerifyHashCommitment(b *testing.B) {
	var salt [32]byte
	data := []byte("proof-data")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = proofs.VerifyHashCommitment("root", data, salt)
	}
}
