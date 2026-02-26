package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestVerifyProof_Valid(t *testing.T) {
	// Proof must be at least 128 bytes to pass the size guard
	proof := make([]byte, 128)
	inputs := []byte("inputs")
	ok, err := internal.VerifyProof(proof, inputs)
	if err != nil {
		t.Fatalf("Expected no error for valid-sized proof, got: %v", err)
	}
	if !ok {
		t.Error("Expected true for valid-sized proof")
	}
}

func TestVerifyProof_TooSmall(t *testing.T) {
	// Proof shorter than 128 bytes should be rejected
	proof := make([]byte, 64)
	inputs := []byte("inputs")
	ok, err := internal.VerifyProof(proof, inputs)
	if err == nil {
		t.Fatal("Expected error for undersized proof, got nil")
	}
	if ok {
		t.Error("Expected false for undersized proof")
	}
}
