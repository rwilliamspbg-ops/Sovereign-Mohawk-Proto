package internal

import "testing"

// This file pins the numeric values of two Lean modules from the sibling
// CausalMohawkBridge project (Mathlib-free Lean 4.14.0):
//
//   - CausalMohawkBridge.Chernoff -- the integer Chernoff tail bound
//   - CausalMohawkBridge.Lorentz  -- affine Lorentz maps and the Minkowski
//     quadratic form Q(t,j) = t^2 - j^2
//
// The Go helpers below transcribe the Lean definitions equation by equation;
// the expected values are the `#eval` outputs of those definitions on the
// same inputs (checked with `lake env lean` at Lean 4.14.0). A mismatch means
// the Go transcription and the Lean spec have diverged.
//
// Chernoff.lean:
//
//	choose _ 0         = 1
//	choose 0 (_ + 1)   = 0
//	choose (n+1) (k+1) = choose n k + choose n (k+1)
//	sumTo 0 f          = f 0
//	sumTo (n+1) f      = sumTo n f + f (n+1)
//	tail k m           = sumTo m (fun i => if i < k then 0 else choose m i)
//	binomial m z       : sumTo m (fun i => choose m i * z^i) = (1+z)^m
//	tail_bound m k (hz : 1 ≤ z) : z^k * tail k m ≤ (1+z)^m
//
// Lorentz.lean:
//
//	lorentz_interval_aux a b x y :
//	  (a*x + b*y)^2 - (b*x + a*y)^2 = (a^2 - b^2)*(x^2 - y^2)
//	ALorentz.apply L (t,j) = (a*t + b*j + ct, b*t + a*j + cj)
//	Q (t,j) = t^2 - j^2
//	Q_apply_sub L p q : Q (L.apply p - L.apply q) = Q (p - q)   -- given a^2-b^2=1

// leanChoose transcribes Chernoff.choose. It returns the binomial coefficient
// C(n,k); Chernoff.choose_gt proves it is 0 when k > n.
func leanChoose(n, k int) int {
	if k == 0 {
		return 1
	}
	if n == 0 {
		return 0
	}
	return leanChoose(n-1, k-1) + leanChoose(n-1, k)
}

// leanSumTo transcribes Chernoff.sumTo: sumTo n f = sum_{i=0}^{n} f(i).
func leanSumTo(n int, f func(int) int) int {
	sum := 0
	for i := 0; i <= n; i++ {
		sum += f(i)
	}
	return sum
}

// leanTail transcribes Chernoff.tail: the unweighted upper binomial tail
// sum_{i=k}^{m} C(m,i).
func leanTail(k, m int) int {
	return leanSumTo(m, func(i int) int {
		if i < k {
			return 0
		}
		return leanChoose(m, i)
	})
}

// leanPow is integer exponentiation, matching Int.pow in the Lean modules
// (exponents are natural numbers).
func leanPow(base, exp int) int {
	result := 1
	for i := 0; i < exp; i++ {
		result *= base
	}
	return result
}

// leanBinomialLHS transcribes the left-hand side of Chernoff.binomial:
// sumTo m (fun i => choose m i * z^i).
func leanBinomialLHS(m, z int) int {
	return leanSumTo(m, func(i int) int {
		return leanChoose(m, i) * leanPow(z, i)
	})
}

// lorentzIntervalLHS transcribes the left-hand side of
// Lorentz.lorentz_interval_aux.
func lorentzIntervalLHS(a, b, x, y int) int {
	return (a*x+b*y)*(a*x+b*y) - (b*x+a*y)*(b*x+a*y)
}

// lorentzIntervalRHS transcribes the right-hand side of
// Lorentz.lorentz_interval_aux.
func lorentzIntervalRHS(a, b, x, y int) int {
	return (a*a - b*b) * (x*x - y*y)
}

// affineLorentz transcribes Lorentz.ALorentz.apply.
type affineLorentz struct {
	a, b, ct, cj int
}

func (l affineLorentz) apply(t, j int) (int, int) {
	return l.a*t + l.b*j + l.ct, l.b*t + l.a*j + l.cj
}

// lorentzQ transcribes Lorentz.Q.
func lorentzQ(t, j int) int { return t*t - j*j }

// TestChernoffLeanCorrespondence checks the Go transcription of
// CausalMohawkBridge.Chernoff against the `#eval` values of the Lean
// definitions on the same inputs.
func TestChernoffLeanCorrespondence(t *testing.T) {
	t.Run("choose_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name string
			n, k int
			want int
		}{
			{"n5_k3", 5, 3, 10},
			{"n5_k0", 5, 0, 1},
			{"n0_k0", 0, 0, 1},
			{"n0_k1", 0, 1, 0},
			{"n5_k6_above_diagonal", 5, 6, 0},
			{"n10_k5", 10, 5, 252},
		}
		for _, c := range cases {
			if got := leanChoose(c.n, c.k); got != c.want {
				t.Fatalf("%s: choose(%d,%d)=%d, want %d (Lean #eval)", c.name, c.n, c.k, got, c.want)
			}
		}
	})

	t.Run("sumTo_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name string
			n    int
			f    func(int) int
			want int
		}{
			{"identity_n3", 3, func(i int) int { return i }, 6},
			{"choose4_n4", 4, func(i int) int { return leanChoose(4, i) }, 16},
			{"pow2_n5", 5, func(i int) int { return leanPow(2, i) }, 63},
		}
		for _, c := range cases {
			if got := leanSumTo(c.n, c.f); got != c.want {
				t.Fatalf("%s: sumTo %d f=%d, want %d (Lean #eval)", c.name, c.n, got, c.want)
			}
		}
	})

	t.Run("tail_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name string
			k, m int
			want int
		}{
			{"k3_m5", 3, 5, 16},
			{"k0_m5_full_sum", 0, 5, 32},
			{"k5_m5_single_term", 5, 5, 1},
			{"k6_m5_empty", 6, 5, 0},
			{"k2_m4", 2, 4, 11},
			{"k1_m3", 1, 3, 7},
		}
		for _, c := range cases {
			if got := leanTail(c.k, c.m); got != c.want {
				t.Fatalf("%s: tail(%d,%d)=%d, want %d (Lean #eval)", c.name, c.k, c.m, got, c.want)
			}
		}
	})

	t.Run("binomial_identity_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name       string
			m, z, want int
		}{
			{"m5_z2", 5, 2, 243},
			{"m5_z_neg1", 5, -1, 0},
			{"m6_z3", 6, 3, 4096},
			{"m0_z2", 0, 2, 1},
			{"m4_z1", 4, 1, 16},
		}
		for _, c := range cases {
			lhs := leanBinomialLHS(c.m, c.z)
			rhs := leanPow(1+c.z, c.m)
			if lhs != rhs {
				t.Fatalf("%s: sumTo %d (choose %d i * %d^i)=%d, want (1+%d)^%d=%d (Lean binomial)",
					c.name, c.m, c.m, c.z, lhs, c.z, c.m, rhs)
			}
			if lhs != c.want {
				t.Fatalf("%s: binomial identity value=%d, want %d (Lean #eval)", c.name, lhs, c.want)
			}
		}
	})

	t.Run("tail_bound_z2_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name             string
			k, m             int
			wantLHS, wantRHS int
		}{
			// The required pin: 2^3 * 16 = 128 <= 243 = 3^5.
			{"k3_m5", 3, 5, 128, 243},
			{"k0_m5", 0, 5, 32, 243},
			{"k5_m5", 5, 5, 32, 243},
			{"k2_m4", 2, 4, 44, 81},
		}
		for _, c := range cases {
			gotLHS := leanPow(2, c.k) * leanTail(c.k, c.m)
			gotRHS := leanPow(3, c.m)
			if gotLHS != c.wantLHS || gotRHS != c.wantRHS {
				t.Fatalf("%s: 2^%d * tail(%d,%d)=%d and 3^%d=%d, want %d and %d (Lean #eval)",
					c.name, c.k, c.k, c.m, gotLHS, c.m, gotRHS, c.wantLHS, c.wantRHS)
			}
			if gotLHS > gotRHS {
				t.Fatalf("%s: tail_bound violated: %d > %d", c.name, gotLHS, gotRHS)
			}
		}
	})

	t.Run("tail_bound_cleared_form_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name             string
			k, m             int
			wantLHS, wantRHS int
		}{
			// The required pin: 16 * 2^8 = 4096 <= 7776 = 2^5 * 3^5.
			{"k3_m5", 3, 5, 4096, 7776},
			{"k2_m4", 2, 4, 704, 1296},
		}
		for _, c := range cases {
			gotLHS := leanTail(c.k, c.m) * leanPow(2, c.m+c.k)
			gotRHS := leanPow(2, c.m) * leanPow(3, c.m)
			if gotLHS != c.wantLHS || gotRHS != c.wantRHS {
				t.Fatalf("%s: tail(%d,%d)*2^(%d+%d)=%d and 2^%d*3^%d=%d, want %d and %d (Lean #eval)",
					c.name, c.k, c.m, c.m, c.k, gotLHS, c.m, c.m, gotRHS, c.wantLHS, c.wantRHS)
			}
			if gotLHS > gotRHS {
				t.Fatalf("%s: cleared tail_bound violated: %d > %d", c.name, gotLHS, gotRHS)
			}
		}
	})
}

// TestLorentzLeanCorrespondence checks the Go transcription of
// CausalMohawkBridge.Lorentz against the `#eval` values of the Lean
// definitions on the same inputs.
func TestLorentzLeanCorrespondence(t *testing.T) {
	t.Run("interval_identity_matches_lean_eval", func(t *testing.T) {
		cases := []struct {
			name       string
			a, b, x, y int
			want       int
		}{
			{"a3_b2_x5_y7", 3, 2, 5, 7, -120},
			{"a_neg4_b1_x2_y_neg3", -4, 1, 2, -3, -75},
			{"a5_b_neg5_x2_y2", 5, -5, 2, 2, 0},
			{"a2_b3_x7_y_neg5", 2, 3, 7, -5, -120},
		}
		for _, c := range cases {
			lhs := lorentzIntervalLHS(c.a, c.b, c.x, c.y)
			rhs := lorentzIntervalRHS(c.a, c.b, c.x, c.y)
			if lhs != rhs {
				t.Fatalf("%s: (a*x+b*y)^2-(b*x+a*y)^2=%d, want (a^2-b^2)*(x^2-y^2)=%d (Lean lorentz_interval_aux)",
					c.name, lhs, rhs)
			}
			if lhs != c.want {
				t.Fatalf("%s: lorentz_interval_aux value=%d, want %d (Lean #eval)", c.name, lhs, c.want)
			}
		}
	})

	t.Run("affine_map_preserves_Q_on_differences", func(t *testing.T) {
		// Over the integers, a^2 - b^2 = 1 forces (a,b) = (±1,0), so these
		// are the affine maps the Lean ALorentz hypothesis admits.
		cases := []struct {
			name  string
			l     affineLorentz
			p, q  [2]int
			wantQ int
		}{
			{"a1_b0_ct4_cj_neg3", affineLorentz{1, 0, 4, -3}, [2]int{1, 2}, [2]int{4, -1}, 0},
			{"a_neg1_b0_ct7_cj11", affineLorentz{-1, 0, 7, 11}, [2]int{5, -2}, [2]int{-3, 6}, 0},
			{"identity_translation_free", affineLorentz{1, 0, 0, 0}, [2]int{3, 1}, [2]int{1, 2}, 3},
			{"a_neg1_b0_ct_neg5_cj2", affineLorentz{-1, 0, -5, 2}, [2]int{10, 4}, [2]int{3, 9}, 24},
		}
		for _, c := range cases {
			if got := c.l.a*c.l.a - c.l.b*c.l.b; got != 1 {
				t.Fatalf("%s: a^2-b^2=%d, want 1 (ALorentz hypothesis)", c.name, got)
			}
			pt, qt := c.l.apply(c.p[0], c.p[1])
			ps, qs := c.l.apply(c.q[0], c.q[1])
			got := lorentzQ(pt-ps, qt-qs)
			want := lorentzQ(c.p[0]-c.q[0], c.p[1]-c.q[1])
			if got != want {
				t.Fatalf("%s: Q(apply p - apply q)=%d, want Q(p-q)=%d (Lean Q_apply_sub)",
					c.name, got, want)
			}
			if got != c.wantQ {
				t.Fatalf("%s: preserved Q=%d, want %d (Lean #eval)", c.name, got, c.wantQ)
			}
		}
	})

	t.Run("affine_difference_matches_interval_aux", func(t *testing.T) {
		// For arbitrary (a,b), the same algebra gives
		// Q(apply p - apply q) = (a^2 - b^2) * Q(p - q); this is
		// lorentz_interval_aux applied to the affine difference.
		cases := []struct {
			name      string
			l         affineLorentz
			p, q      [2]int
			wantScale int
		}{
			{"a3_b2", affineLorentz{3, 2, 4, -3}, [2]int{4, 1}, [2]int{1, 2}, 40},
			{"a2_b1", affineLorentz{2, 1, 0, 0}, [2]int{5, -2}, [2]int{1, 1}, 21},
		}
		for _, c := range cases {
			pt, qt := c.l.apply(c.p[0], c.p[1])
			ps, qs := c.l.apply(c.q[0], c.q[1])
			got := lorentzQ(pt-ps, qt-qs)
			want := (c.l.a*c.l.a - c.l.b*c.l.b) * lorentzQ(c.p[0]-c.q[0], c.p[1]-c.q[1])
			if got != want {
				t.Fatalf("%s: Q(apply p - apply q)=%d, want (a^2-b^2)*Q(p-q)=%d", c.name, got, want)
			}
			if got != c.wantScale {
				t.Fatalf("%s: scaled Q=%d, want %d", c.name, got, c.wantScale)
			}
		}
	})
}
