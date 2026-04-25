package test

import (
	"crypto/ed25519"
	"crypto/rand"
	"errors"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestBatchVerifierWithComputeProof(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	msg := []byte("m1")
	sig := ed25519.Sign(priv, msg)

	bv := internal.NewBatchVerifier(2)
	results, err := bv.VerifySignaturesWithComputeProof(
		[]ed25519.PublicKey{pub},
		[][]byte{msg},
		[][]byte{sig},
		[][]byte{[]byte("trace")},
		[][]byte{[]byte("proof")},
		func(tracePayload []byte, proofPayload []byte) (bool, error) {
			return string(tracePayload) == "trace" && string(proofPayload) == "proof", nil
		},
	)
	if err != nil {
		t.Fatalf("verify signatures with compute proof: %v", err)
	}
	if len(results) != 1 || !results[0] {
		t.Fatalf("expected successful combined verification, got %#v", results)
	}
}

func TestBatchVerifierWithComputeProofError(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	msg := []byte("m1")
	sig := ed25519.Sign(priv, msg)

	bv := internal.NewBatchVerifier(2)
	_, err = bv.VerifySignaturesWithComputeProof(
		[]ed25519.PublicKey{pub},
		[][]byte{msg},
		[][]byte{sig},
		[][]byte{[]byte("trace")},
		[][]byte{[]byte("proof")},
		func(_ []byte, _ []byte) (bool, error) {
			return false, errors.New("backend down")
		},
	)
	if err == nil {
		t.Fatal("expected compute proof verifier error")
	}
}
