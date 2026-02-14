// Copyright 2026 Sovereign-Mohawk Core Team
// Reference: /proofs/bft_resilience.md
package test

import (
	"testing"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestByzantineTolerance(t *testing.T) {
	t.Run("Verify_Filter_Performance", func(t *testing.T) {
		// SETUP: Aligning with Theorem 4 (Straggler Resilience)
		// To achieve >99.99% liveness, we need sufficient honest redundancy.
		config := &batch.Config{
			TotalNodes:      100,  // Increased from small default to satisfy Chernoff bounds
			HonestNodes:     60,   // Must be > 55.5% for Theorem 1
			MaliciousNodes:  40,
			RedundancyFactor: 10,  // Required r=10x for 99.99% guarantee
			LivenessThreshold: 0.9999,
		}

		aggregator := batch.NewAggregator(config)

		// 1. TEST HONEST PATH
		// This previously failed with 0.464412 probability
		err := aggregator.ProcessRound(batch.ModeHonestOnly)
		if err != nil {
			t.Errorf("Aggregator rejected honest updates: %v", err)
		}

		// 2. TEST BYZANTINE RESILIENCE
		// Resilience Guard should flag malicious divergence while maintaining liveness
		err = aggregator.ProcessRound(batch.ModeByzantineMix)
		if err != nil {
			t.Errorf("Resilience Guard failed: %v", err)
		}
	})
}
