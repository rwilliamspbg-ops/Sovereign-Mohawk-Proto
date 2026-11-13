package test

import (
	"math"
	"math/big"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func FuzzRDPShardStep(f *testing.F) {
	f.Add("shard-1", 0.5)
	f.Add("", 0.0)
	f.Fuzz(func(t *testing.T, shardID string, epsilon float64) {
		a := internal.NewRDPAccountant(10.0, 1e-5)
		a.RecordShardStep(shardID, epsilon)
		eps := a.GetCurrentEpsilon()
		if math.IsNaN(eps) || math.IsInf(eps, 0) {
			t.Fatalf("invalid epsilon: %v", eps)
		}
	})
}

// FuzzRDPShardStepSemantic asserts monotonicity, shard-ledger accounting, and
// agreement between CheckBudget and the reported epsilon.
func FuzzRDPShardStepSemantic(f *testing.F) {
	f.Add("shard-1", 0.5)
	f.Add("", 0.0)
	f.Fuzz(func(t *testing.T, shardID string, epsilon float64) {
		if math.IsNaN(epsilon) || math.IsInf(epsilon, 0) {
			t.Skip()
		}
		a := internal.NewRDPAccountant(10.0, 1e-5)
		before := a.GetCurrentEpsilon()
		a.RecordShardStep(shardID, epsilon)
		after := a.GetCurrentEpsilon()
		if math.IsNaN(after) || math.IsInf(after, 0) {
			t.Fatalf("invalid epsilon: %v", after)
		}
		if epsilon >= 0 && after < before-1e-9 {
			t.Fatalf("epsilon decreased: %v -> %v", before, after)
		}
		// The shard sub-ledger must equal the recorded epsilon.
		shard := a.GetShardEpsilonRat(shardID)
		want := new(big.Rat).SetFloat64(epsilon)
		if shard.Cmp(want) != 0 {
			t.Fatalf("shard epsilon %s != recorded %s", shard.RatString(), want.RatString())
		}
		// Budget check must agree with the reported epsilon.
		err := a.CheckBudget()
		reported := a.GetCurrentEpsilonRat()
		budget := big.NewRat(10, 1)
		if (reported.Cmp(budget) > 0) != (err != nil) {
			t.Fatalf("budget mismatch: reported=%s err=%v", reported.RatString(), err)
		}
	})
}
