package test

import (
	"math/big"
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func weightAggregatorConfig() *batch.Config {
	return &batch.Config{
		TotalNodes:       1000,
		HonestNodes:      900,
		MaliciousNodes:   100,
		RedundancyFactor: 10,
	}
}

// TestBatchAggregator_ZKWeightCircuitAttestation verifies that the aggregator's
// preferred path checks a WeightUpdateCircuit proof against the caller's
// statement, and fails closed when the statement does not match.
func TestBatchAggregator_ZKWeightCircuitAttestation(t *testing.T) {
	skipWeightProofInRace(t)
	in, w := honestWeightFixture()
	encoded, st, err := internalpkg.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("ProveWeightUpdate: %v", err)
	}

	agg := batch.NewAggregator(weightAggregatorConfig())
	agg.WeightProof = encoded
	agg.WeightStatement = &st
	if err := agg.ProcessRound(batch.ModeHonest); err != nil {
		t.Fatalf("ProcessRound with valid weight proof: %v", err)
	}
	if !agg.Verified {
		t.Fatal("expected Verified=true after successful weight attestation")
	}

	// A statement that does not match the proof must be rejected.
	bad := st
	bad.UpdateHash = new(big.Int).Add(st.UpdateHash, big.NewInt(1))
	agg2 := batch.NewAggregator(weightAggregatorConfig())
	agg2.WeightProof = encoded
	agg2.WeightStatement = &bad
	if err := agg2.ProcessRound(batch.ModeHonest); err == nil {
		t.Fatal("expected ProcessRound to reject a mismatched weight statement")
	}

	// Fail-closed: no proof at all and no legacy opt-in. The package-wide
	// init() in zz_legacy_attestation_env_test.go forces the opt-in on for this
	// package, so clear it explicitly to exercise the real default.
	t.Setenv("MOHAWK_ALLOW_LEGACY_ATTESTATION", "")
	agg3 := batch.NewAggregator(weightAggregatorConfig())
	if err := agg3.ProcessRound(batch.ModeHonest); err == nil {
		t.Fatal("expected ProcessRound to fail closed without a proof")
	}
}

// TestBatchAggregator_ZKWeightProof_ByzantineMix runs the same prove-and-verify
// path under a 10% Byzantine mix: the proof still has to verify before the round
// is accepted, and the Byzantine count is still filtered.
func TestBatchAggregator_ZKWeightProof_ByzantineMix(t *testing.T) {
	in, w := honestWeightFixture()
	encoded, st, err := internalpkg.ProveWeightUpdate(in, w)
	if err != nil {
		t.Fatalf("ProveWeightUpdate: %v", err)
	}

	cfg := weightAggregatorConfig()
	agg := batch.NewAggregator(cfg)
	agg.WeightProof = encoded
	agg.WeightStatement = &st
	if err := agg.ProcessRound(batch.ModeByzantineMix); err != nil {
		t.Fatalf("ProcessRound(ByzantineMix) with valid weight proof: %v", err)
	}
	if !agg.Verified {
		t.Fatal("expected Verified=true after successful weight attestation")
	}
	if agg.FilteredCount != cfg.MaliciousNodes {
		t.Fatalf("FilteredCount = %d, want %d", agg.FilteredCount, cfg.MaliciousNodes)
	}
}
