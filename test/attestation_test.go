package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestAttestationProofVerification(t *testing.T) {
	t.Parallel()

	// 1. Setup Configuration
	// This mirrors the MOHAWK architecture requirements for node distribution.
	cfg := &batch.Config{
		TotalNodes:       100,
		HonestNodes:      70,
		MaliciousNodes:   30,
		RedundancyFactor: 5,
	}

	agg := batch.NewAggregator(cfg)

	// --- SCENARIO 1: Honest Round ---
	// Simulate an all-honest round where all nodes provide valid TPM/Wasm attestations.
	t.Run("HonestRound", func(t *testing.T) {
		err := agg.ProcessRound(batch.ModeHonest)
		if err != nil {
			t.Fatalf("Honest round failed to process: %v", err)
		}

		// Verify the aggregator successfully generated and verified the proof
		if !agg.Verified {
			t.Error("Aggregator failed to verify proof for a known honest round")
		}
	})

	// --- SCENARIO 2: Byzantine Round ---
	// Simulate a round with a mix of malicious nodes to ensure filtering works.
	t.Run("ByzantineMix", func(t *testing.T) {
		err := agg.ProcessRound(batch.ModeByzantineMix)
		if err != nil {
			t.Fatalf("Byzantine round failed unexpectedly: %v", err)
		}

		// Assert that the security logic actually caught and filtered the malicious nodes.
		// We expect at least some nodes to be dropped based on the Config.
		if agg.FilteredCount == 0 {
			t.Error("Security failure: 0 malicious nodes were filtered during ModeByzantineMix")
		}

		// Ensure the final aggregate was still marked as verified after filtering
		if !agg.Verified {
			t.Error("Aggregate should be verified even after filtering malicious inputs")
		}
	})
}
