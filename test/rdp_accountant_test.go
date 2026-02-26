package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestRDPAccountant_InitialBudget(t *testing.T) {
	acc := internal.NewRDPAccountant(2.0, 1e-5)
	if err := acc.CheckBudget(); err != nil {
		t.Fatalf("Expected no error on fresh accountant, got: %v", err)
	}
}

func TestRDPAccountant_RecordStep_WithinBudget(t *testing.T) {
	acc := internal.NewRDPAccountant(2.0, 1e-5)
	acc.RecordStep(0.1)
	if err := acc.CheckBudget(); err != nil {
		t.Fatalf("Expected budget within limit after small step, got: %v", err)
	}
}

func TestRDPAccountant_CheckBudget_Exceeded(t *testing.T) {
	acc := internal.NewRDPAccountant(2.0, 1e-5)
	// Accumulate enough to exceed the budget
	acc.RecordStep(100.0)
	if err := acc.CheckBudget(); err == nil {
		t.Fatal("Expected budget exceeded error, got nil")
	}
}

func TestRDPAccountant_GetCurrentEpsilon_Zero(t *testing.T) {
	acc := internal.NewRDPAccountant(2.0, 1e-5)
	eps := acc.GetCurrentEpsilon()
	if eps != 0 {
		t.Errorf("Expected epsilon=0 on fresh accountant, got %.4f", eps)
	}
}

func TestRDPAccountant_GetCurrentEpsilon_NonZero(t *testing.T) {
	acc := internal.NewRDPAccountant(2.0, 1e-5)
	acc.RecordStep(0.5)
	eps := acc.GetCurrentEpsilon()
	if eps <= 0 {
		t.Errorf("Expected positive epsilon after recording a step, got %.4f", eps)
	}
}
