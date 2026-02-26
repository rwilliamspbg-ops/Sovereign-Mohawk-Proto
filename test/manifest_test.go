package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
)

func TestValidateCommunicationComplexity_Valid(t *testing.T) {
	m := &manifest.Manifest{
		TaskID: "t1",
		NodeID: "n1",
	}
	// d=1000, n=100 → limit = 1000 * log10(100) = 2000; actual ≈ 204 → well within bound
	err := m.ValidateCommunicationComplexity(1000, 100)
	if err != nil {
		t.Fatalf("Expected communication complexity to be valid, got: %v", err)
	}
}

func TestValidateCommunicationComplexity_Violated(t *testing.T) {
	longID := string(make([]byte, 500))
	m := &manifest.Manifest{
		TaskID: longID,
		NodeID: longID,
	}
	// d=1, n=10 → limit = 1 * log10(10) = 1; actual ≈ 1200 → exceeds 2*limit
	err := m.ValidateCommunicationComplexity(1, 10)
	if err == nil {
		t.Fatal("Expected communication complexity violation, got nil error")
	}
}
