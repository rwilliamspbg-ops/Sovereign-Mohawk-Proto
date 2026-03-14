package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
)

func TestBuildPlan(t *testing.T) {
	plan, err := hva.BuildPlan(1000000, 4096)
	if err != nil {
		t.Fatalf("expected HVA plan to build, got %v", err)
	}
	if len(plan.Levels) < 2 {
		t.Fatalf("expected multi-level HVA plan, got %d levels", len(plan.Levels))
	}
	if err := plan.Validate(); err != nil {
		t.Fatalf("expected valid HVA plan, got %v", err)
	}
}

func TestMinimumHonestNodes(t *testing.T) {
	if got := hva.MinimumHonestNodes(9); got != 5 {
		t.Fatalf("expected 5 honest nodes for 9 total, got %d", got)
	}
}
