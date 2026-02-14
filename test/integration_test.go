// Copyright 2026 Sovereign-Mohawk Core Team
// Reference: /proofs/bft_resilience.md
package test

import (
	"testing"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestByzantineTolerance(t *testing.T) {
	// config setup to satisfy 99.99% liveness (Theorem 4)
	cfg := &batch.Config{
		TotalNodes:       100,
		HonestNodes:      60, // > 55.5% per Theorem 1
		MaliciousNodes:   40,
		RedundancyFactor: 10, // Required r=10x
	}

	aggregator := batch.NewAggregator(cfg)

	t.Run("Verify_Honest_Liveness", func(t *testing.T) {
		// Test with honest nodes only
		err := aggregator.ProcessRound(batch.ModeHonestOnly)
		if err != nil {
			t.Fatalf("Liveness check failed: %v", err)
		}
	})

	t.Run("Verify_Byzantine_Filtering", func(t *testing.T) {
		// Test with malicious actors injected
		err := aggregator.ProcessRound(batch.ModeByzantineMix)
		if err != nil {
			t.Fatalf("Resilience Guard failed under attack: %v", err)
		}
	})
}
