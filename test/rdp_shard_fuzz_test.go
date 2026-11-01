package test

import (
	"math"
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
