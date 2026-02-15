// attestation_test.go
package test

import (
    "testing"

    "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestProcessRoundAttestation(t *testing.T) {
    t.Parallel()

    // Good case: majority honest → expect success (attestation/proof should pass internally)
    cfgGood := &batch.Config{
        TotalNodes:       100,
        HonestNodes:      70,
        MaliciousNodes:   30,
        RedundancyFactor: 5,
    }
    aggGood := batch.NewAggregator(cfgGood)
    err := aggGood.ProcessRound(batch.ModeByzantineMix)
    if err != nil {
        t.Errorf("Expected success with honest majority, but got error: %v "+
            "(attestation or proof verification likely failed internally)", err)
    }

    // Bad case: too many malicious → expect error (attestation/safety rejection)
    cfgBad := &batch.Config{
        TotalNodes:       100,
        HonestNodes:      20,
        MaliciousNodes:   80,
        RedundancyFactor: 5,
    }
    aggBad := batch.NewAggregator(cfgBad)
    err = aggBad.ProcessRound(batch.ModeByzantineMix)
    if err == nil {
        t.Error("Expected error/failure with excessive malicious nodes " +
            "(attestation should have rejected the round), but succeeded")
    } else {
        t.Logf("Correctly rejected bad round: %v", err)
    }
}
