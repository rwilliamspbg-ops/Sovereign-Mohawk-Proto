package test

import (
	"math/big"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// TestRDPAccountantLeanCorrespondence checks RDPAccountant.TotalEpsilon
// against outputs independently computed from the Lean spec (composeRDP in
// proofs/Specification/Privacy.lean) via `#eval` on the same inputs. Both
// sides use exact rational arithmetic (Lean's ℚ, Go's *big.Rat), so the
// correspondence is checked for exact equality, not approximation — see
// proofs/Refinement/RDPAccountant.lean for the full documented
// correspondence, including the (ε, δ)-DP conversion gap this test does not
// cover (CheckBudget applies a conversion the Lean spec does not model).
func TestRDPAccountantLeanCorrespondence(t *testing.T) {
	t.Run("flat_list_matches_composeRDP", func(t *testing.T) {
		// composeRDP [1/10, 3/20, 7/100, 1/5] = 13/25 (Lean #eval).
		acc := internal.NewRDPAccountant(1000.0, 1e-5)
		acc.RecordStepRat(big.NewRat(1, 10))
		acc.RecordStepRat(big.NewRat(3, 20))
		acc.RecordStepRat(big.NewRat(7, 100))
		acc.RecordStepRat(big.NewRat(1, 5))

		want := big.NewRat(13, 25)
		if acc.TotalEpsilon.Cmp(want) != 0 {
			t.Fatalf("TotalEpsilon = %s, want %s (Lean composeRDP value)", acc.TotalEpsilon.RatString(), want.RatString())
		}
	})

	t.Run("shard_split_matches_flat_composeRDP", func(t *testing.T) {
		// Same four steps as above, grouped into two shards instead of one
		// flat sequence. composeRDP_append / accountant_impl_append prove
		// composition doesn't care how the list is split; this checks Go's
		// per-shard ledger agrees empirically: total is still 13/25.
		acc := internal.NewRDPAccountant(1000.0, 1e-5)
		acc.RecordShardStepRat("shard-a", big.NewRat(1, 10))
		acc.RecordShardStepRat("shard-a", big.NewRat(3, 20))
		acc.RecordShardStepRat("shard-b", big.NewRat(7, 100))
		acc.RecordShardStepRat("shard-b", big.NewRat(1, 5))

		want := big.NewRat(13, 25)
		if acc.TotalEpsilon.Cmp(want) != 0 {
			t.Fatalf("TotalEpsilon = %s, want %s (Lean composeRDP value)", acc.TotalEpsilon.RatString(), want.RatString())
		}

		wantShardA := big.NewRat(1, 4) // 1/10 + 3/20 = 5/20 = 1/4
		if got := acc.GetShardEpsilonRat("shard-a"); got.Cmp(wantShardA) != 0 {
			t.Fatalf("shard-a epsilon = %s, want %s", got.RatString(), wantShardA.RatString())
		}
	})

	t.Run("gaussian_step_matches_gaussianStepRDP", func(t *testing.T) {
		// gaussianStepRDP 10 2 = 10/(2*2*2) = 5/4 (Lean #eval); Go's fixed
		// Alpha is 10.0 (set in NewRDPAccountant), matching Lean's alpha=10
		// input here. 1.25 is exactly representable in float64, so the
		// float64->big.Rat conversion in RecordStep is exact.
		acc := internal.NewRDPAccountant(1000.0, 1e-5)
		if err := acc.RecordGaussianStepRDP(2.0); err != nil {
			t.Fatalf("RecordGaussianStepRDP failed: %v", err)
		}

		want := big.NewRat(5, 4)
		if acc.TotalEpsilon.Cmp(want) != 0 {
			t.Fatalf("TotalEpsilon = %s, want %s (Lean gaussianStepRDP value)", acc.TotalEpsilon.RatString(), want.RatString())
		}
	})

	t.Run("empty_ledger_matches_composeRDP_nil", func(t *testing.T) {
		// composeRDP [] = 0 (Lean #eval).
		acc := internal.NewRDPAccountant(1000.0, 1e-5)
		if acc.TotalEpsilon.Sign() != 0 {
			t.Fatalf("TotalEpsilon = %s, want 0 (Lean composeRDP [] value)", acc.TotalEpsilon.RatString())
		}
	})
}
