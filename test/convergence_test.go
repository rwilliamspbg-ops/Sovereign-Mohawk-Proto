package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestConvergenceMonitor_IsConverging_Below(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	// gradNorm well below threshold + zetaSq
	if !cm.IsConverging(0.05) {
		t.Error("Expected convergence for grad norm below threshold")
	}
}

func TestConvergenceMonitor_IsConverging_Above(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	// gradNorm above effective threshold (0.1 + 0.01 = 0.11)
	if cm.IsConverging(1.0) {
		t.Error("Expected non-convergence for grad norm well above threshold")
	}
}

func TestConvergenceMonitor_EffectiveThreshold(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	got := cm.EffectiveThreshold()
	if got != 0.11 {
		t.Errorf("Expected effective threshold 0.11, got %.4f", got)
	}
}

func TestConvergenceMonitor_EnvelopeBound(t *testing.T) {
	cm := internal.NewConvergenceMonitor(0.1, 0.01)
	got := cm.EnvelopeBound(100, 1000)
	want := 1.0/(2.0*100.0*1000.0) + 0.01
	if got != want {
		t.Errorf("Expected envelope %.10f, got %.10f", want, got)
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
