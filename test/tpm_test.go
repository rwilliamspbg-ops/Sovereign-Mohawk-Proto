package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

func TestVerifyByzantineResilience_Valid(t *testing.T) {
	// 101 total, 40 malicious → 101 > 2*40+1 = 81 → passes
	ok, err := tpm.VerifyByzantineResilience(101, 40)
	if err != nil {
		t.Fatalf("Expected resilience check to pass, got: %v", err)
	}
	if !ok {
		t.Error("Expected true for sufficient node count")
	}
}

func TestVerifyByzantineResilience_Violated(t *testing.T) {
	// 10 total, 6 malicious → 10 <= 2*6 = 12 → fails
	ok, err := tpm.VerifyByzantineResilience(10, 6)
	if err == nil {
		t.Fatal("Expected security threshold violation error, got nil")
	}
	if ok {
		t.Error("Expected false when threshold is violated")
	}
}

func TestCalculateGlobalTolerance(t *testing.T) {
	tiers := []int{5, 10, 15}
	total := tpm.CalculateGlobalTolerance(tiers)
	if total != 30 {
		t.Errorf("Expected global tolerance 30, got %d", total)
	}
}

func TestCalculateGlobalTolerance_Empty(t *testing.T) {
	total := tpm.CalculateGlobalTolerance([]int{})
	if total != 0 {
		t.Errorf("Expected 0 for empty tiers, got %d", total)
	}
}

func TestGetVerifiedQuote(t *testing.T) {
	quote, err := tpm.GetVerifiedQuote("node-001")
	if err != nil {
		t.Fatalf("Expected quote retrieval to succeed, got: %v", err)
	}
	if len(quote) == 0 {
		t.Error("Expected non-empty quote")
	}
	if err := tpm.Verify("node-001", quote); err != nil {
		t.Fatalf("Expected quote verification to succeed, got: %v", err)
	}
}

func TestVerifyByzantineResilience_StrictBoundary(t *testing.T) {
	// 9 total nodes require 5 honest nodes, so 4 Byzantine nodes are the maximum.
	ok, err := tpm.VerifyByzantineResilience(9, 4)
	if err != nil || !ok {
		t.Fatalf("Expected 4 Byzantine nodes out of 9 to pass, got ok=%v err=%v", ok, err)
	}

	ok, err = tpm.VerifyByzantineResilience(9, 5)
	if err == nil || ok {
		t.Fatalf("Expected 5 Byzantine nodes out of 9 to violate the 55.5%% boundary")
	}
}
