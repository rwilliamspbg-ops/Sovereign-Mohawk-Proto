package test

import (
    "testing"
    "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestAttestationViaAggregation(t *testing.T) {
    cfg := &batch.Config{
        TotalNodes:       100,
        HonestNodes:      70,
        MaliciousNodes:   30,
        RedundancyFactor: 5,
    }

    agg := batch.NewAggregator(cfg)

    err := agg.ProcessRound(batch.ModeByzantineMix)
    if err != nil {
        t.Fatalf("Attestation/proof failed in honest-majority round: %v", err)
    }
    t.Log("Aggregation succeeded → zk-SNARK proofs verified and attestation passed for valid updates")
}
