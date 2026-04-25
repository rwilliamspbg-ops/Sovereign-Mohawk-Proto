package test

import (
	"testing"

	privacy "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/privacy"
)

func TestPrivacyOrchestratorAllocatesWithinBudget(t *testing.T) {
	o := privacy.NewOrchestrator(2.0, 0.2, 1.2)
	res, err := o.Allocate(privacy.AllocationRequest{
		ShardID:    "health-shard",
		Class:      privacy.SensitivityHealthcare,
		ShardSize:  5000,
		DriftScore: 0.4,
	})
	if err != nil {
		t.Fatalf("allocate: %v", err)
	}
	if res.AllocatedEps < 0.2 || res.AllocatedEps > 1.2 {
		t.Fatalf("allocation out of bounds: %.6f", res.AllocatedEps)
	}
	if res.RemainingBudget <= 0 {
		t.Fatalf("expected positive remaining budget, got %.6f", res.RemainingBudget)
	}
}

func TestPrivacyOrchestratorExhaustion(t *testing.T) {
	o := privacy.NewOrchestrator(0.3, 0.2, 0.3)
	_, err := o.Allocate(privacy.AllocationRequest{ShardID: "s1", Class: privacy.SensitivityPublic, ShardSize: 1000, DriftScore: 1.0})
	if err != nil {
		t.Fatalf("unexpected first allocation failure: %v", err)
	}
	_, err = o.Allocate(privacy.AllocationRequest{ShardID: "s2", Class: privacy.SensitivityPublic, ShardSize: 1000, DriftScore: 1.0})
	if err == nil {
		t.Fatal("expected global budget exhaustion on second allocation")
	}
}
