package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestVerifyProof_Valid(t *testing.T) {
	// Use the deterministic genesis proof: A=G1gen, B=G2gen, C=−G1gen.
	// This satisfies e(−A,B)·e(α,β)·e(IC₀,γ)·e(C,δ)=1 under the genesis VK.
	proof := internal.GenesisProofBytes()
	ok, err := internal.VerifyProof(proof, nil)
	if err != nil {
		t.Fatalf("Expected no error for genesis proof, got: %v", err)
	}
	if !ok {
		t.Error("Expected true for valid genesis proof")
	}
}

func TestVerifyProof_TooSmall(t *testing.T) {
	// Proof shorter than 128 bytes must be rejected before any curve operations.
	proof := make([]byte, 64)
	ok, err := internal.VerifyProof(proof, nil)
	if err == nil {
		t.Fatal("Expected error for undersized proof, got nil")
	}
	if ok {
		t.Error("Expected false for undersized proof")
	}
}

func TestVerifyProof_InvalidPoint(t *testing.T) {
	// 128 bytes of zeros are NOT valid compressed BN254 points (not on the curve).
	proof := make([]byte, 128)
	ok, err := internal.VerifyProof(proof, nil)
	if err == nil {
		t.Fatal("Expected error for all-zero (invalid-point) proof, got nil")
	}
	if ok {
		t.Error("Expected false for all-zero proof")
	}
}

func TestVerifyProof_WrongProof(t *testing.T) {
	// Corrupt the genesis proof's C point — pairing check must return false.
	proof := internal.GenesisProofBytes()
	// Flip a bit in the C component (bytes 96–127)
	proof[96] ^= 0x80
	// The modified bytes may fail point parsing or pairing; either is acceptable.
	ok, _ := internal.VerifyProof(proof, nil)
	if ok {
		t.Error("Expected false (or parse error) for corrupted proof, got true")
	}
}
