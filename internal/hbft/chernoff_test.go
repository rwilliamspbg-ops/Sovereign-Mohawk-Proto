package hbft

import (
	"testing"
)

func TestChernoffFailureBoundDeploymentScale(t *testing.T) {
	// Matches chernoff_hierarchical_bound_deployment_scale: T=200, c=50000,
	// k=25000, p=0.1, z=2 -> bound <= 200/10^1000 (effectively 0).
	bound, err := ChernoffFailureBound(200, 50000, 25000, 0.1, 2.0)
	if err != nil {
		t.Fatal(err)
	}
	if bound > 1e-10 {
		t.Fatalf("deployment-scale bound too loose: %g", bound)
	}
}

func TestChernoffFailureBoundVacuous(t *testing.T) {
	// Tiny committees with high p produce a vacuous bound (>1, clamped to 1).
	bound, err := ChernoffFailureBound(1, 3, 1, 0.5, 2.0)
	if err != nil {
		t.Fatal(err)
	}
	if bound != 1 {
		t.Fatalf("expected clamped 1, got %g", bound)
	}
}

func TestValidateChernoffBoundFailClosed(t *testing.T) {
	cfg := SimulatorConfig{
		Topology: TopologyConfig{
			Tiers:              1,
			CommitteesPerTier:  1,
			NodesPerCommittee:  8,
		},
		ByzantineRate: 0.5,
		Adversary:     &OutlierAdversary{},
		Dimension:     2,
		Seed:          1,
	}
	// This topology should fail the bound (high p, tiny committees).
	s, err := NewSimulator(cfg)
	if err == nil {
		t.Fatal("expected NewSimulator to reject vacuous topology")
	}
	_ = s
}

func TestValidateChernoffBoundPasses(t *testing.T) {
	cfg := SimulatorConfig{
		Topology: TopologyConfig{
			Tiers:              2,
			CommitteesPerTier:  100,
			NodesPerCommittee:  50,
		},
		ByzantineRate: 0.1,
		Adversary:     &OutlierAdversary{},
		Dimension:     2,
		Seed:          1,
	}
	s, err := NewSimulator(cfg)
	if err != nil {
		t.Fatalf("expected pass, got %v", err)
	}
	if err := s.ValidateChernoffBound(1.0); err != nil {
		t.Fatalf("ValidateChernoffBound: %v", err)
	}
}
