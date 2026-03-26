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

func TestLoadDPConfig_Defaults(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "")
	t.Setenv("MOHAWK_DP_EPSILON_BUDGET", "")
	t.Setenv("MOHAWK_DP_DELTA", "")

	cfg := internal.LoadDPConfig()
	if cfg.Sigma != 0.5 {
		t.Fatalf("expected default sigma=0.5, got %f", cfg.Sigma)
	}
	if cfg.TargetEpsilon != 27.14 {
		t.Fatalf("expected default epsilon budget=27.14, got %f", cfg.TargetEpsilon)
	}
	if cfg.Delta != 1e-5 {
		t.Fatalf("expected default delta=1e-5, got %f", cfg.Delta)
	}
}

func TestLoadDPConfig_EnvOverride(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "1.36")
	t.Setenv("MOHAWK_DP_EPSILON_BUDGET", "9.6")
	t.Setenv("MOHAWK_DP_DELTA", "0.00001")

	cfg := internal.LoadDPConfig()
	if cfg.Sigma != 1.36 {
		t.Fatalf("expected sigma=1.36 from env, got %f", cfg.Sigma)
	}
	if cfg.TargetEpsilon != 9.6 {
		t.Fatalf("expected epsilon budget=9.6 from env, got %f", cfg.TargetEpsilon)
	}
	if cfg.Delta != 1e-5 {
		t.Fatalf("expected delta=1e-5 from env, got %f", cfg.Delta)
	}
}

func TestNewAggregator_UsesDPConfig(t *testing.T) {
	t.Setenv("MOHAWK_DP_EPSILON_BUDGET", "15.5")
	t.Setenv("MOHAWK_DP_DELTA", "0.00002")

	agg := internal.NewAggregator(internal.Regional)
	if agg.Accountant.MaxBudget != 15.5 {
		t.Fatalf("expected accountant max budget=15.5, got %f", agg.Accountant.MaxBudget)
	}
	if agg.Accountant.TargetDelta != 2e-5 {
		t.Fatalf("expected accountant delta=2e-5, got %f", agg.Accountant.TargetDelta)
	}
}
