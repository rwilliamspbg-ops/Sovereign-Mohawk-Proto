package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestConvergenceMonitor_IsConverging_Below(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	// gradNorm well below threshold + sqrt(zetaSq)
	if !cm.IsConverging(0.05) {
		t.Error("Expected convergence for grad norm below threshold")
	}
}

func TestConvergenceMonitor_IsConverging_Above(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	// gradNorm above effective threshold (0.1 + sqrt(0.01) = 0.2)
	if cm.IsConverging(1.0) {
		t.Error("Expected non-convergence for grad norm well above threshold")
	}
}

func TestConvergenceMonitor_GetHeterogeneityEstimate_Initial(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	est := cm.GetHeterogeneityEstimate()
	if est != 0.01 {
		t.Errorf("Expected initial heterogeneity estimate 0.01, got %.4f", est)
	}
}

func TestConvergenceMonitor_GetHeterogeneityEstimate_AfterHistory(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	cm.IsConverging(0.05)
	cm.IsConverging(0.04)
	est := cm.GetHeterogeneityEstimate()
	if est <= 0 {
		t.Errorf("Expected positive heterogeneity estimate after history, got %.4f", est)
	}
}
