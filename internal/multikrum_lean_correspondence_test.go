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
