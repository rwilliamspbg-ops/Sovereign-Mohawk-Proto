package test

import (
	"crypto/sha256"
	"fmt"
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

// FuzzVerifyHashCommitmentSemantic recomputes the expected SHA-256 commitment
// independently and asserts the verifier accepts exactly the matching root.
func FuzzVerifyHashCommitmentSemantic(f *testing.F) {
	f.Add("abc", []byte("proof"), make([]byte, 32))
	f.Fuzz(func(t *testing.T, expectedRoot string, proofData []byte, salt []byte) {
		if len(salt) != 32 {
			t.Skip()
		}
		var s [32]byte
		copy(s[:], salt)
		h := sha256.New()
		h.Write(proofData)
		if s != ([32]byte{}) {
			h.Write(s[:])
		}
		actual := fmt.Sprintf("%x", h.Sum(nil))
		ok, err := proofs.VerifyHashCommitment(expectedRoot, proofData, s)
		if expectedRoot == actual {
			if !ok || err != nil {
				t.Fatalf("expected acceptance, got ok=%v err=%v", ok, err)
			}
			return
		}
		if ok {
			t.Fatalf("expected rejection for root %q, got acceptance (actual %q)", expectedRoot, actual)
		}
	})
}
