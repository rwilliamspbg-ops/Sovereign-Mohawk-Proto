package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestStragglerMonitor_CalculateSuccessProbability_HighNodes(t *testing.T) {
	sm := internal.NewStragglerMonitor()
	// With 1000 nodes and 50% dropout, redundancy=10 makes success near 1.0
	prob := sm.CalculateSuccessProbability(1000, 0.5)
	if prob < 0.9999 {
		t.Errorf("Expected success probability >= 0.9999 for 1000 nodes, got %.6f", prob)
	}
}

func TestStragglerMonitor_CalculateSuccessProbability_LowNodes(t *testing.T) {
	sm := internal.NewStragglerMonitor()
	// With 1 node, success probability should be lower
	prob := sm.CalculateSuccessProbability(1, 0.5)
	if prob >= 0.9999 {
		t.Errorf("Expected success probability < 0.9999 for 1 node, got %.6f", prob)
	}
}

func TestStragglerMonitor_ValidateLiveness_Pass(t *testing.T) {
	sm := internal.NewStragglerMonitor()
	// 1000 active nodes → should meet 99.99% liveness threshold
	if err := sm.ValidateLiveness(1000, 1000); err != nil {
		t.Fatalf("Expected liveness to pass for 1000 nodes, got: %v", err)
	}
}

func TestStragglerMonitor_ValidateLiveness_Fail(t *testing.T) {
	sm := internal.NewStragglerMonitor()
	// 1 active node → should fail liveness threshold
	if err := sm.ValidateLiveness(1, 1); err == nil {
		t.Fatal("Expected liveness failure for 1 node, got nil")
	}
}
