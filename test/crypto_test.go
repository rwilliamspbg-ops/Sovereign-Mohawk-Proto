package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/crypto"
)

func TestVerifyBatchIntegrity_Valid(t *testing.T) {
	ok, err := crypto.VerifyBatchIntegrity("batch-abc-123")
	if err != nil {
		t.Fatalf("Expected no error for valid batch ID, got: %v", err)
	}
	if !ok {
		t.Error("Expected true for valid batch ID")
	}
}

func TestVerifyBatchIntegrity_Empty(t *testing.T) {
	ok, err := crypto.VerifyBatchIntegrity("")
	if err == nil {
		t.Fatal("Expected error for empty batch ID, got nil")
	}
	if ok {
		t.Error("Expected false for empty batch ID")
	}
}
