package hbft

import (
	"fmt"
	"math"
	"math/big"
	"testing"
)

// This file cross-checks the runtime Chernoff bound in chernoff.go against the
// integer Chernoff tail bound proved in the sibling Mathlib-free Lean project
// CausalMohawkBridge (and referenced by proofs/LeanFormalization):
//
//	tail(k, m) = sum_{i>=k} C(m, i)
//	2^k * tail(k, m) <= 3^m
//
// Equivalently, dividing by 2^m:
//
//	tail(k, m) / 2^m <= 3^m / 2^(m+k)
//
// At p = 0.5, z = 2, T = 1 the runtime function computes
//
//	ChernoffFailureBound(1, m, k, 0.5, 2) = (1 - p + p*z)^m / z^k
//	                                    = 1.5^m / 2^k
//	                                    = 3^m / 2^(m+k)
//
// so the two formulations must agree exactly (up to float rounding) at these
// shared toy parameters. The integer tail is computed independently here with
// math/big; the Lean project is not imported.

// leanBinomial returns C(n, k) exactly.
func leanBinomial(n, k int64) *big.Int {
	if k < 0 || k > n {
		return big.NewInt(0)
	}
	if k > n-k {
		k = n - k
	}
	result := big.NewInt(1)
	for j := int64(1); j <= k; j++ {
		// result = result * (n - k + j) / j; the division is exact.
		result.Mul(result, big.NewInt(n-k+j))
		result.Quo(result, big.NewInt(j))
	}
	return result
}

// leanTail returns tail(k, m) = sum_{i=k}^{m} C(m, i) exactly.
func leanTail(k, m int) *big.Int {
	tail := big.NewInt(0)
	for i := k; i <= m; i++ {
		tail.Add(tail, leanBinomial(int64(m), int64(i)))
	}
	return tail
}

// TestChernoffLeanToyExample pins the documented toy case m=5, k=3:
// tail(3,5) = C(5,3)+C(5,4)+C(5,5) = 10+5+1 = 16, so 2^3 * 16 = 128 <= 3^5 = 243,
// and the runtime bound must equal 3^5 / 2^(5+3) = 243/256.
func TestChernoffLeanToyExample(t *testing.T) {
	const (
		m        = 5
		k        = 3
		wantTail = 16
	)

	tail := leanTail(k, m)
	if got := tail.Int64(); got != wantTail {
		t.Fatalf("tail(%d,%d) = %d, want %d", k, m, got, wantTail)
	}

	// Exact integer Lean bound: 2^k * tail(k,m) <= 3^m.
	lhs := new(big.Int).Lsh(big.NewInt(1), uint(k))
	lhs.Mul(lhs, tail)
	rhs := new(big.Int).Exp(big.NewInt(3), big.NewInt(int64(m)), nil)
	if lhs.Cmp(rhs) > 0 {
		t.Fatalf("integer Lean bound violated: 2^%d * %s = %s > 3^%d = %s",
			k, tail, lhs, m, rhs)
	}

	// Runtime float bound must match 3^m / 2^(m+k).
	got, err := ChernoffFailureBound(1, m, k, 0.5, 2.0)
	if err != nil {
		t.Fatalf("ChernoffFailureBound: %v", err)
	}
	want := 243.0 / 256.0
	if rel := math.Abs(got-want) / want; rel > 1e-12 {
		t.Fatalf("ChernoffFailureBound(1,%d,%d,0.5,2) = %.17g, want %.17g (rel err %.3g)",
			m, k, got, want, rel)
	}
	t.Logf("m=%d k=%d: tail=%s, 2^k*tail=%s <= 3^m=%s, bound=%.17g = 3^m/2^(m+k)",
		m, k, tail, lhs, rhs, got)
}

// TestChernoffLeanIntegerAgreement checks the runtime float bound and the exact
// integer Lean bound at several shared (m, k) pairs. Every pair is chosen in the
// non-vacuous regime 3^m / 2^(m+k) < 1 so the runtime function's clamp to 1
// does not mask the comparison.
func TestChernoffLeanIntegerAgreement(t *testing.T) {
	cases := []struct {
		m, k int
	}{
		{5, 3},
		{8, 5},
		{10, 6},
		{20, 12},
		{50, 30},
		{100, 60},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(fmt.Sprintf("m=%d,k=%d", tc.m, tc.k), func(t *testing.T) {
			m, k := int64(tc.m), int64(tc.k)

			// Exact expected value 3^m / 2^(m+k) as a rational, then float64.
			num := new(big.Int).Exp(big.NewInt(3), big.NewInt(m), nil)
			den := new(big.Int).Lsh(big.NewInt(1), uint(m+k))
			want, _ := new(big.Rat).SetFrac(num, den).Float64()
			if want >= 1 {
				t.Fatalf("case m=%d k=%d is vacuous (3^m/2^(m+k) = %g >= 1); pick k larger",
					tc.m, tc.k, want)
			}

			// Runtime float bound.
			got, err := ChernoffFailureBound(1, tc.m, tc.k, 0.5, 2.0)
			if err != nil {
				t.Fatalf("ChernoffFailureBound: %v", err)
			}
			if rel := math.Abs(got-want) / want; rel > 1e-12 {
				t.Fatalf("bound = %.17g, want %.17g (rel err %.3g)", got, want, rel)
			}

			// Exact integer Lean bound: 2^k * tail(k,m) <= 3^m.
			tail := leanTail(tc.k, tc.m)
			lhs := new(big.Int).Lsh(big.NewInt(1), uint(k))
			lhs.Mul(lhs, tail)
			rhs := new(big.Int).Exp(big.NewInt(3), big.NewInt(m), nil)
			if lhs.Cmp(rhs) > 0 {
				t.Fatalf("integer Lean bound violated: 2^%d * %s = %s > 3^%d = %s",
					tc.k, tail, lhs, tc.m, rhs)
			}

			// Cross-check the equivalent tail-probability form against the
			// runtime float bound: tail(k,m)/2^m <= 3^m/2^(m+k).
			tailFloat := new(big.Float).SetInt(tail)
			tailFloat.Quo(tailFloat, new(big.Float).SetInt(new(big.Int).Lsh(big.NewInt(1), uint(m))))
			tailProb, _ := tailFloat.Float64()
			if tailProb > got*(1+1e-12) {
				t.Fatalf("tail/2^m = %g exceeds runtime bound %g", tailProb, got)
			}

			t.Logf("m=%d k=%d: tail=%s, 2^k*tail=%s <= 3^m=%s, bound=%.17g, tail/2^m=%.17g",
				tc.m, tc.k, tail, lhs, rhs, got, tailProb)
		})
	}
}
