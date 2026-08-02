package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/proofs"
)

func TestVerifyHashCommitment(t *testing.T) {
	// Root of an empty SHA256 hash (the prototype default)
	root := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	data := []byte("")
	salt := [32]byte{}

	isValid, err := proofs.VerifyHashCommitment(root, data, salt)
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}
	if !isValid {
		t.Fatal("Expected proof to be valid")
	}
}

func TestVerifyHashCommitment_Invalid(t *testing.T) {
	root := "invalid_root"
	data := []byte("some data")
	salt := [32]byte{}

	isValid, _ := proofs.VerifyHashCommitment(root, data, salt)
	if isValid {
		t.Fatal("Expected proof to be invalid for mismatched root")
	}
}
