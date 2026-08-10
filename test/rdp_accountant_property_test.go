package test

import (
	"math"
	"math/big"
	"math/rand/v2"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// Property-based regression net for row 13 of proofs/FORMAL_TRACEABILITY_MATRIX.md
// (Refinement/RDPAccountant.lean). These properties mirror the machine-checked
// Lean facts accountant_impl_monotone_append (monotonicity),
// accountant_impl_append / composeRDP_append ("grouping doesn't change the
// total"), and rdp_budget_conversion_shift (CheckBudget's raw-ledger-vs-
// converted-budget equivalence): instead of the existing handful of fixed
// pinned vectors, generate many random valid inputs and check the invariants
// hold across all of them. This is an empirical Go-side regression net, not
// a proof -- the Lean side remains the source of truth.

// randNonNegRat generates a small, exact, non-negative rational epsilon step
// (numerator/denominator both bounded so accumulated sums stay easy to
// reason about and never approach big.Rat performance cliffs).
func randNonNegRat(rng *rand.Rand) *big.Rat {
	num := int64(rng.IntN(1000))
	den := int64(1 + rng.IntN(1000))
	return big.NewRat(num, den)
}

// TestRDPAccountant_Property_MonotoneAppend checks that recording any
// non-negative epsilon step never decreases the cumulative ledger, matching
// accountant_impl_monotone_append.
func TestRDPAccountant_Property_MonotoneAppend(t *testing.T) {
	rng := rand.New(rand.NewPCG(10, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		acc := internal.NewRDPAccountant(1e9, 1e-5) // budget irrelevant here; only the ledger is checked
		steps := 1 + rng.IntN(20)
		before := new(big.Rat)
		for s := 0; s < steps; s++ {
			step := randNonNegRat(rng)
			before.Set(acc.TotalEpsilon)
			acc.RecordStepRat(step)
			if acc.TotalEpsilon.Cmp(before) < 0 {
				t.Fatalf("trial %d step %d: TotalEpsilon decreased from %s to %s after recording non-negative step %s",
					trial, s, before.RatString(), acc.TotalEpsilon.RatString(), step.RatString())
			}
		}
	}
}

// TestRDPAccountant_Property_ShardGroupingInvariant checks that splitting
// the same sequence of steps across an arbitrary number of shards and
// summing the per-shard ledgers gives the same total as recording them all
// flat -- the runtime-side analogue of accountant_impl_append /
// composeRDP_append ("grouping doesn't change the total"), generalized here
// across many random partitions instead of the existing fixed 2-shard vector.
func TestRDPAccountant_Property_ShardGroupingInvariant(t *testing.T) {
	rng := rand.New(rand.NewPCG(11, 0))
	const trials = 100
	for trial := 0; trial < trials; trial++ {
		numSteps := 1 + rng.IntN(30)
		numShards := 1 + rng.IntN(5)
		steps := make([]*big.Rat, numSteps)
		shardOf := make([]int, numSteps)
		for i := range steps {
			steps[i] = randNonNegRat(rng)
			shardOf[i] = rng.IntN(numShards)
		}

		flat := internal.NewRDPAccountant(1e9, 1e-5)
		sharded := internal.NewRDPAccountant(1e9, 1e-5)
		shardIDs := make([]string, numShards)
		for i := range shardIDs {
			shardIDs[i] = "shard-" + string(rune('A'+i))
		}

		for i, step := range steps {
			flat.RecordStepRat(step)
			sharded.RecordShardStepRat(shardIDs[shardOf[i]], step)
		}

		if flat.TotalEpsilon.Cmp(sharded.TotalEpsilon) != 0 {
			t.Fatalf("trial %d: flat total %s != sharded global total %s (numSteps=%d numShards=%d)",
				trial, flat.TotalEpsilon.RatString(), sharded.TotalEpsilon.RatString(), numSteps, numShards)
		}

		shardSum := new(big.Rat)
		for _, id := range shardIDs {
			shardSum.Add(shardSum, sharded.GetShardEpsilonRat(id))
		}
		if flat.TotalEpsilon.Cmp(shardSum) != 0 {
			t.Fatalf("trial %d: flat total %s != sum of per-shard ledgers %s (numSteps=%d numShards=%d)",
				trial, flat.TotalEpsilon.RatString(), shardSum.RatString(), numSteps, numShards)
		}
	}
}

// TestRDPAccountant_Property_CheckBudgetMatchesConversionShift
// independently recomputes the RDP-to-(epsilon,delta)-DP conversion
// CheckBudget applies internally and checks that CheckBudget's actual
// error/nil outcome always agrees with it -- a runtime regression net for
// rdp_budget_conversion_shift (the row-13 Lean fact that bounding the
// converted quantity by budget is equivalent to bounding the raw ledger by
// budget-conversion, not by budget itself).
func TestRDPAccountant_Property_CheckBudgetMatchesConversionShift(t *testing.T) {
	rng := rand.New(rand.NewPCG(12, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		maxEpsilon := 0.5 + rng.Float64()*10 // (0.5, 10.5)
		delta := math.Pow(10, -(1 + rng.Float64()*9))
		acc := internal.NewRDPAccountant(maxEpsilon, delta)
		acc.Alpha = 1.5 + rng.Float64()*48.5 // (1.5, 50), always > 1

		steps := rng.IntN(10)
		for s := 0; s < steps; s++ {
			acc.RecordStepRat(randNonNegRat(rng))
		}

		wantErr := acc.TotalEpsilon.Sign() != 0
		var wantExceeded bool
		if wantErr {
			conversion := math.Log(1.0/acc.TargetDelta) / (acc.Alpha - 1.0)
			current := new(big.Rat).Set(acc.TotalEpsilon)
			current.Add(current, new(big.Rat).SetFloat64(conversion))
			wantExceeded = current.Cmp(acc.MaxBudget) > 0
		}

		err := acc.CheckBudget()
		gotExceeded := err != nil
		if wantErr && gotExceeded != wantExceeded {
			t.Fatalf("trial %d: CheckBudget exceeded=%v, independently recomputed exceeded=%v (totalEpsilon=%s maxBudget=%s alpha=%f delta=%g)",
				trial, gotExceeded, wantExceeded, acc.TotalEpsilon.RatString(), acc.MaxBudget.RatString(), acc.Alpha, delta)
		}
		if !wantErr && err != nil {
			t.Fatalf("trial %d: expected no error for a fresh (zero-epsilon) accountant, got: %v", trial, err)
		}
	}
}
