package test

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestBatchVerifier_VerifySignatures_Valid(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("Key generation failed: %v", err)
	}

	msg := []byte("test-message")
	sig := ed25519.Sign(priv, msg)

	bv := batch.NewBatchVerifier(10)
	results, err := bv.VerifySignatures(
		[]ed25519.PublicKey{pub},
		[][]byte{msg},
		[][]byte{sig},
	)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if len(results) != 1 || !results[0] {
		t.Error("Expected valid signature to be verified as true")
	}
}

func TestBatchVerifier_VerifySignatures_Invalid(t *testing.T) {
	pub, _, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("Key generation failed: %v", err)
	}

	msg := []byte("test-message")
	badSig := make([]byte, ed25519.SignatureSize)

	bv := batch.NewBatchVerifier(10)
	results, err := bv.VerifySignatures(
		[]ed25519.PublicKey{pub},
		[][]byte{msg},
		[][]byte{badSig},
	)
	if err != nil {
		t.Fatalf("Expected no error on invalid sig, got: %v", err)
	}
	if len(results) != 1 || results[0] {
		t.Error("Expected invalid signature to be verified as false")
	}
}

func TestBatchVerifier_VerifySignatures_LengthMismatch(t *testing.T) {
	pub, _, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("Key generation failed: %v", err)
	}

	bv := batch.NewBatchVerifier(10)
	_, err = bv.VerifySignatures(
		[]ed25519.PublicKey{pub},
		[][]byte{},
		[][]byte{},
	)
	if err == nil {
		t.Fatal("Expected error for mismatched input lengths, got nil")
	}
}

func TestBatchVerifier_VerifySignatures_AutoBatchSize(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("Key generation failed: %v", err)
	}

	msg := []byte("auto-batch")
	sig := ed25519.Sign(priv, msg)

	bv := batch.NewBatchVerifier(0)
	results, err := bv.VerifySignatures(
		[]ed25519.PublicKey{pub},
		[][]byte{msg},
		[][]byte{sig},
	)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}
	if len(results) != 1 || !results[0] {
		t.Error("Expected valid signature to verify with auto batch size")
	}
}
