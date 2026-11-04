package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestStragglerMonitor_CorrelatedFailureBound(t *testing.T) {
	sm := internal.NewStragglerMonitor()
	rho0 := sm.CorrelatedFailureBound(0.5, 0)
	rho1 := sm.CorrelatedFailureBound(0.5, 1)
	if rho1 < rho0 {
		t.Fatalf("correlated (rho=1) should be >= independent (rho=0): %v < %v", rho1, rho0)
	}
	// rho=0 recovers independent p^r
	indep := sm.PerRegionFailureBound(0.5)
	if rho0 != indep {
		t.Fatalf("rho=0 should equal independent bound: %v != %v", rho0, indep)
	}
}

func TestStragglerMonitor_AdversarialFailureBound(t *testing.T) {
	sm := internal.NewStragglerMonitor() // r=10
	if got := sm.AdversarialFailureBound(5); got != 0 {
		t.Fatalf("budget 5 < r 10 should be 0, got %v", got)
	}
	if got := sm.AdversarialFailureBound(10); got != 1 {
		t.Fatalf("budget 10 >= r 10 should be 1, got %v", got)
	}
	if got := sm.AdversarialFailureBound(15); got != 1 {
		t.Fatalf("budget 15 >= r 10 should be 1, got %v", got)
	}
}

func TestStragglerMonitor_CorrelatedMonitor(t *testing.T) {
	sm := internal.NewCorrelatedStragglerMonitor(0.5)
	if sm.CorrelationFactor != 0.5 {
		t.Fatalf("CorrelationFactor = %v, want 0.5", sm.CorrelationFactor)
	}
	// Correlated monitor should report higher (or equal) failure than independent.
	indep := internal.NewStragglerMonitor()
	if sm.EffectiveFailureBound(0.5) < indep.EffectiveFailureBound(0.5) {
		t.Fatal("correlated effective failure should be >= independent")
	}
}