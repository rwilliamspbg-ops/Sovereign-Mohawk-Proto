package hbft

import (
	"testing"
)

// Property-based regression net for Refinement/BFT.lean.
// Mirrors bft_impl_refines_spec: Go's stricter precondition (n > 2f+2)
// implies Lean's spec safety (2f < n).

func bftSpecSafe(n, f int) bool { return 2*f < n }
func bftImplSafe(n, f int) bool { return 2*f+2 < n }

func TestBFT_Property_ImplImpliesSpec(t *testing.T) {
	for f := 0; f <= 20; f++ {
		for n := 0; n <= 60; n++ {
			if bftImplSafe(n, f) && !bftSpecSafe(n, f) {
				t.Fatalf("impl safe but spec unsafe: n=%d f=%d", n, f)
			}
		}
	}
}

func TestBFT_Property_GapWitness(t *testing.T) {
	// n=4, f=1 is spec-safe but impl-unsafe (documented gap).
	if !bftSpecSafe(4, 1) {
		t.Fatal("expected spec-safe for n=4 f=1")
	}
	if bftImplSafe(4, 1) {
		t.Fatal("expected impl-unsafe for n=4 f=1")
	}
}

func TestBFT_Property_ConcreteGuard(t *testing.T) {
	// 7 nodes, 2 byzantine — both safe.
	if !bftSpecSafe(7, 2) {
		t.Fatal("expected spec-safe for 7,2")
	}
	if !bftImplSafe(7, 2) {
		t.Fatal("expected impl-safe for 7,2")
	}
}

func TestBFT_Property_NewSimulatorRejectsUnsafeTopology(t *testing.T) {
	// NodesPerCommittee=4, f=1 -> 4 <= 2*1+2=4, should be rejected.
	cfg := SimulatorConfig{
		Topology: TopologyConfig{
			Tiers:              1,
			CommitteesPerTier:  1,
			NodesPerCommittee:  4,
		},
		ByzantineRate: 0.1,
		Adversary:     OutlierAdversary{},
		Dimension:     2,
		Seed:          1,
	}
	if _, err := NewSimulator(cfg); err == nil {
		t.Fatal("expected NewSimulator to reject unsafe topology (n<=2f+2)")
	}
}

func TestBFT_Property_NewSimulatorAcceptsSafeTopology(t *testing.T) {
	cfg := SimulatorConfig{
		Topology: TopologyConfig{
			Tiers:              1,
			CommitteesPerTier:  1,
			NodesPerCommittee:  27,
		},
		ByzantineRate: 0.1,
		Adversary:     OutlierAdversary{},
		Dimension:     2,
		Seed:          1,
	}
	if _, err := NewSimulator(cfg); err != nil {
		t.Fatalf("expected accept, got %v", err)
	}
}