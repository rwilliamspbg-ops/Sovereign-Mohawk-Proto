package batch

import (
	"crypto/ed25519"
	"testing"
)

func FuzzVerifySignatures(f *testing.F) {
	f.Add([]byte("hello"))
	f.Fuzz(func(t *testing.T, msg []byte) {
		pub, priv, err := ed25519.GenerateKey(nil)
		if err != nil {
			t.Fatal(err)
		}
		sig := ed25519.Sign(priv, msg)
		bv := NewBatchVerifier(4)
		res, err := bv.VerifySignatures([]ed25519.PublicKey{pub}, [][]byte{msg}, [][]byte{sig})
		if err != nil {
			t.Fatal(err)
		}
		if len(res) != 1 || !res[0] {
			t.Fatalf("expected valid signature, got %v", res)
		}
	})
}