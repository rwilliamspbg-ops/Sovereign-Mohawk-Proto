package test

import (
	"math/big"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// TestRDPConversionBound checks Go's actual math.Log-based RDP-to-(ε,δ)-DP
// conversion (GetCurrentEpsilonRat, internal/rdp_accountant.go) against a
// two-sided rational bound genuinely machine-checked in
// proofs/Refinement/RDPLogBound.lean's rdpToApproxDP_bound theorem — not
// exact equality, since Real.log is irrational-valued and noncomputable
// (unlike the additive ledger's exact #eval-pinned correspondence in
// rdp_accountant_lean_correspondence_test.go, this closes the gap that
// row 13 of FORMAL_TRACEABILITY_MATRIX.md previously left as
// conversion_gap_formalized_not_closed).
//
// Each case's lower/upper big.Rat bound was pinned by #eval-ing
// epsLowerRat/epsUpperRat in RDPLogBound.lean at the same (k, r) reduction
// witness documented in that file's comments for the given delta. alpha is
// fixed at 10.0 throughout, matching NewRDPAccountant's production default
// and rdpToApproxDP_bound's alpha=10 specialization.
func TestRDPConversionBound(t *testing.T) {
	// Record a known, exact rational epsilonRDP step before reading
	// GetCurrentEpsilonRat: at TotalEpsilon == 0, Go short-circuits to a
	// bare zero (skipping the conversion term entirely, see
	// GetCurrentEpsilonRat's own zero-ledger branch) — a real, deliberate
	// Go-side special case, not something this test works around silently.
	// Recording a nonzero step exercises the actual conversion formula
	// this test is meant to check.
	epsilonRDP := big.NewRat(1, 1000)

	cases := []struct {
		name  string
		delta float64
		// lower/upper are epsLowerRat(k,r)/epsUpperRat(k,r) from
		// RDPLogBound.lean, i.e. the bound on the conversion term alone
		// (epsilonRDP=0 in the Lean theorem); epsilonRDP is added on the
		// Go side below since rdpToApproxDP_bound's bound is additive in
		// epsilonRDP.
		lowerNum, lowerDen string
		upperNum, upperDen string
	}{
		{
			// delta=1e-5 (NewRDPAccountant's default), x=1/delta=100000,
			// k=16 (2^16=65536 <= 100000 < 2^17=131072)
			name:     "delta_1e-5_default",
			delta:    1e-5,
			lowerNum: "65807601479681", lowerDen: "51794375000000",
			upperNum: "19252978219448747", upperDen: "14916780000000000",
		},
		{
			// delta=1e-3, x=1000, k=9 (2^9=512 <= 1000 < 2^10=1024)
			name:     "delta_1e-3",
			delta:    1e-3,
			lowerNum: "5574172479254161", lowerDen: "7458390000000000",
			upperNum: "5959626219495839", upperDen: "7458390000000000",
		},
		{
			// delta=1e-8, x=100000000, k=26 (2^26=67108864 <= 1e8 < 2^27=134217728)
			name:     "delta_1e-8",
			delta:    1e-8,
			lowerNum: "844857785055053", lowerDen: "414355000000000",
			upperNum: "3927304225651198751", upperDen: "1909347840000000000",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			acc := internal.NewRDPAccountant(1000.0, tc.delta)
			acc.RecordStepRat(new(big.Rat).Set(epsilonRDP))

			got := acc.GetCurrentEpsilonRat()

			lower := new(big.Rat)
			if _, ok := lower.SetString(tc.lowerNum + "/" + tc.lowerDen); !ok {
				t.Fatalf("bad lower bound literal %s/%s", tc.lowerNum, tc.lowerDen)
			}
			lower.Add(lower, epsilonRDP)

			upper := new(big.Rat)
			if _, ok := upper.SetString(tc.upperNum + "/" + tc.upperDen); !ok {
				t.Fatalf("bad upper bound literal %s/%s", tc.upperNum, tc.upperDen)
			}
			upper.Add(upper, epsilonRDP)

			if got.Cmp(lower) < 0 || got.Cmp(upper) > 0 {
				t.Fatalf("GetCurrentEpsilonRat() = %s (%.6f), want in [%s, %s] = [%.6f, %.6f] (Lean-proven bound, delta=%v)",
					got.RatString(), ratFloat(got),
					lower.RatString(), upper.RatString(), ratFloat(lower), ratFloat(upper), tc.delta)
			}
		})
	}
}

func ratFloat(r *big.Rat) float64 {
	f, _ := r.Float64()
	return f
}
