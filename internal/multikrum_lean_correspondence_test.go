package internal

import "testing"

// TestMultiKrumLeanCorrespondence checks MultiKrumSelect against outputs
// independently computed from the Lean spec (multiKrumSelectImpl in
// proofs/Specification/System.lean) via `#eval` on the same inputs, using
// the parameter mapping documented in proofs/Refinement/MultiKrum.lean:
// Go's (f, derived neighbors = n-f-2) against Lean's raw k = neighbors.
//
// Each case is m=1 (single-Krum), matching the scope of multiKrumSelectImpl,
// which only ever returns one gradient. leanGradient is the exact value
// `multiKrumSelectImpl` printed for k = neighbors on the identical input.
func TestMultiKrumLeanCorrespondence(t *testing.T) {
	cases := []struct {
		name         string
		updates      [][]float64
		f            int // Byzantine bound passed to Go; derives neighbors = n-f-2
		leanSelected int
		leanGradient []float64
	}{
		{
			// n=5, f=1 -> neighbors=2. Three honest gradients clustered near
			// [0.1, 0.1], two far Byzantine outliers.
			name: "n5_f1_honest_cluster",
			updates: [][]float64{
				{0.1, 0.1}, {0.1, 0.1}, {0.12, 0.09}, {100.0, -100.0}, {-99.0, 98.0},
			},
			f:            1,
			leanSelected: 0,
			leanGradient: []float64{0.1, 0.1},
		},
		{
			// n=7, f=2 -> neighbors=3. Four honest gradients near [1,1,1],
			// three far Byzantine outliers.
			name: "n7_f2_honest_cluster",
			updates: [][]float64{
				{1.0, 1.0, 1.0}, {1.1, 0.9, 1.0}, {0.9, 1.1, 1.0}, {1.0, 1.0, 1.1},
				{100.0, -100.0, 0.0}, {-90.0, 90.0, 90.0}, {0.0, 0.0, -200.0},
			},
			f:            2,
			leanSelected: 0,
			leanGradient: []float64{1.0, 1.0, 1.0},
		},
		{
			// n=4, f=0 -> neighbors=2, all-honest (no Byzantine points).
			name: "n4_f0_all_honest",
			updates: [][]float64{
				{2.0, 3.0}, {2.1, 2.9}, {1.9, 3.1}, {2.0, 3.05},
			},
			f:            0,
			leanSelected: 3,
			leanGradient: []float64{2.0, 3.05},
		},
		{
			// n=3, f=0 -> neighbors=1. Three evenly-spaced points give an
			// exact 3-way score tie (each scores 1.0 against its one nearest
			// neighbor); this checks the tie-break rule (lowest index wins)
			// agrees between Lean's argmin? and Go's ranking.
			name: "n3_f0_tie_break",
			updates: [][]float64{
				{0.0}, {1.0}, {2.0},
			},
			f:            0,
			leanSelected: 0,
			leanGradient: []float64{0.0},
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			selected, _, err := MultiKrumSelect(c.updates, c.f, 1)
			if err != nil {
				t.Fatalf("MultiKrumSelect failed: %v", err)
			}
			if len(selected) != 1 {
				t.Fatalf("selected length=%d, want 1 (m=1)", len(selected))
			}
			if selected[0] != c.leanSelected {
				t.Fatalf("selected index=%d, want %d (Lean spec selection)", selected[0], c.leanSelected)
			}
			got := c.updates[selected[0]]
			if len(got) != len(c.leanGradient) {
				t.Fatalf("gradient dim=%d, want %d", len(got), len(c.leanGradient))
			}
			for i := range got {
				if got[i] != c.leanGradient[i] {
					t.Fatalf("gradient[%d]=%v, want %v (Lean spec output)", i, got[i], c.leanGradient[i])
				}
			}
		})
	}
}

// TestMultiKrumLeanCorrespondence_GeneralM extends
// TestMultiKrumLeanCorrespondence to m > 1, closing row 12's "m = 1 only"
// gap on the empirical-correspondence side (the formal side is closed by
// proofs/Refinement/MultiKrum.lean's multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl,
// which proves m=1 general-selection agrees with multiKrumSelectImpl exactly
// -- a real theorem, not an #eval-pinned vector, since both sides there are
// Lean functions). leanSelected/leanGradients were computed via
// `#eval multiKrumSelectManyImpl` on the identical inputs, using the same
// k = neighbors = n-f-2 parameter mapping as the m=1 cases above.
func TestMultiKrumLeanCorrespondence_GeneralM(t *testing.T) {
	cases := []struct {
		name          string
		updates       [][]float64
		f             int
		m             int
		leanSelected  []int
		leanGradients [][]float64
	}{
		{
			// n=7, f=1 -> neighbors=4, m=2. Five honest gradients clustered
			// near [1,1], two far Byzantine outliers.
			name: "n7_f1_m2_honest_cluster",
			updates: [][]float64{
				{1.0, 1.0}, {1.05, 0.95}, {0.95, 1.05}, {1.02, 0.98}, {0.98, 1.02},
				{50.0, -50.0}, {-50.0, 50.0},
			},
			f:            1,
			m:            2,
			leanSelected: []int{0, 3},
			leanGradients: [][]float64{
				{1.0, 1.0}, {1.02, 0.98},
			},
		},
		{
			// n=6, f=1 -> neighbors=3, m=3. Four honest gradients near
			// [2,2,2], two far Byzantine outliers.
			name: "n6_f1_m3_honest_cluster",
			updates: [][]float64{
				{2.0, 2.0, 2.0}, {2.1, 1.9, 2.0}, {1.9, 2.1, 2.0}, {2.0, 2.0, 2.1},
				{100.0, -100.0, 0.0}, {-100.0, 100.0, 0.0},
			},
			f:            1,
			m:            3,
			leanSelected: []int{0, 3, 1},
			leanGradients: [][]float64{
				{2.0, 2.0, 2.0}, {2.0, 2.0, 2.1}, {2.1, 1.9, 2.0},
			},
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			selected, _, err := MultiKrumSelect(c.updates, c.f, c.m)
			if err != nil {
				t.Fatalf("MultiKrumSelect failed: %v", err)
			}
			if len(selected) != c.m {
				t.Fatalf("selected length=%d, want %d", len(selected), c.m)
			}
			if len(selected) != len(c.leanSelected) {
				t.Fatalf("selected length=%d, want %d (Lean spec selection)", len(selected), len(c.leanSelected))
			}
			for i := range selected {
				if selected[i] != c.leanSelected[i] {
					t.Fatalf("selected[%d]=%d, want %d (Lean spec selection, index %d)", i, selected[i], c.leanSelected[i], i)
				}
			}
			for i, idx := range selected {
				got := c.updates[idx]
				want := c.leanGradients[i]
				if len(got) != len(want) {
					t.Fatalf("gradient[%d] dim=%d, want %d", i, len(got), len(want))
				}
				for j := range got {
					if got[j] != want[j] {
						t.Fatalf("gradient[%d][%d]=%v, want %v (Lean spec output)", i, j, got[j], want[j])
					}
				}
			}
		})
	}
}
