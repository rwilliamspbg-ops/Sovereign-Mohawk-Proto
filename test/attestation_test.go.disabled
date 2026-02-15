package test

import (
    "testing"

    "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch" // adjust import if path differs
    // Add more imports if needed, e.g. "context", "time"
)

func TestAttestationProofVerification(t *testing.T) {
    t.Parallel()

    cfg := &batch.Config{
        TotalNodes:       100,
        HonestNodes:      70,
        MaliciousNodes:   30,
        RedundancyFactor: 5,
    }

    agg := batch.NewAggregator(cfg)

    // Simulate honest round → expect valid proof/attestation
    err := agg.ProcessRound(batch.ModeHonest)
    if err != nil {
        t.Fatalf("Honest round failed: %v", err)
    }

    // Check that proof was generated and verified (adapt to your actual API)
    if !agg.LastProofValid() { // replace with real method if different, e.g. agg.Verified()
        t.Error("Proof verification failed for honest aggregation")
    }

    // Simulate Byzantine round → expect filtering/rejection
    err = agg.ProcessRound(batch.ModeByzantineMix)
    if err != nil {
        t.Fatalf("Byzantine round failed unexpectedly: %v", err)
    }

    // Assert malicious updates were attested against / filtered
    if agg.MaliciousFilteredCount() == 0 { // replace with your counter/method
        t.Error("No malicious nodes filtered in Byzantine mode")
    }
}
