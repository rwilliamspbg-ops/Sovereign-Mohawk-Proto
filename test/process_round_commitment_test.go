package test

import (
	"os"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

// TestProcessRound_RequiresGradientCommitmentByDefault verifies that the
// legacy empty-proof fallback is disabled unless explicitly opted in.
func TestProcessRound_RequiresGradientCommitmentByDefault(t *testing.T) {
	t.Setenv("MOHAWK_ALLOW_LEGACY_ATTESTATION", "")

	cfg := &batch.Config{
		TotalNodes:       10,
		HonestNodes:      9,
		MaliciousNodes:   1,
		RedundancyFactor: 2,
	}
	agg := batch.NewAggregator(cfg)

	if err := agg.ProcessRound(batch.ModeHonest); err == nil {
		t.Fatal("expected ProcessRound to fail without a gradient commitment")
	}

	// Ensure env var handling is exercised even if os.Getenv is stubbed.
	_ = os.Getenv
}