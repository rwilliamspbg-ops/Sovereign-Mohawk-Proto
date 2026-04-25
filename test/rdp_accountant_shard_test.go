package test

import (
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestRDPAccountantShardLedger(t *testing.T) {
	acc := internal.NewRDPAccountant(10, 1e-5)
	acc.RecordShardStep("health-1", 0.25)
	acc.RecordShardStep("health-1", 0.25)
	acc.RecordShardStep("public-9", 0.5)

	h := acc.GetShardEpsilonRat("health-1")
	if h.RatString() != "1/2" {
		t.Fatalf("expected health shard epsilon 1/2, got %s", h.RatString())
	}
	p := acc.GetShardEpsilonRat("public-9")
	if p.RatString() != "1/2" {
		t.Fatalf("expected public shard epsilon 1/2, got %s", p.RatString())
	}
}
