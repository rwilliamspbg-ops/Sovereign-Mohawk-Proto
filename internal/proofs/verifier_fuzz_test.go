package proofs

import (
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

func FuzzVerifyHashCommitment(f *testing.F) {
	f.Add("abc", []byte("data"))
	f.Fuzz(func(t *testing.T, expected string, data []byte) {
		h := sha256.Sum256(data)
		actual := hex.EncodeToString(h[:])
		ok, err := VerifyHashCommitment(actual, data, [32]byte{})
		if err != nil || !ok {
			t.Fatalf("valid commitment rejected: %v %v", err, ok)
		}
		// Wrong expected must be rejected.
		if expected != actual {
			if ok2, _ := VerifyHashCommitment(expected, data, [32]byte{}); ok2 {
				t.Fatalf("wrong commitment accepted")
			}
		}
	})
}