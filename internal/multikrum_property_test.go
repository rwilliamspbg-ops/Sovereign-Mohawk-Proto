package internal

import (
	"math/rand/v2"
	"testing"
)

// Property-based regression net for row 12 of proofs/FORMAL_TRACEABILITY_MATRIX.md
// (Refinement/MultiKrum.lean). These properties mirror the @requires/@ensures
// spec comments already on MultiKrumSelect and the machine-checked Lean facts
// go_neighbors_valid / multiKrumSelectSafe_none_outside_envelope /
// multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl: instead of a handful of
// fixed pinned vectors, generate many random valid/invalid inputs and check
// the invariants hold across all of them. This is an empirical Go-side
// regression net, not a proof -- the Lean side remains the source of truth.

func randGradients(rng *rand.Rand, n, dim int) [][]float64 {
	updates := make([][]float64, n)
	for i := range updates {
		row := make([]float64, dim)
		for j := range row {
			row[j] = rng.Float64()*20 - 10 // bounded, always finite
		}
		updates[i] = row
	}
	return updates
}

func cloneGradients(updates [][]float64) [][]float64 {
	out := make([][]float64, len(updates))
	for i, row := range updates {
		out[i] = append([]float64(nil), row...)
	}
	return out
}

// TestMultiKrumSelect_Property_BelowEnvelopeAlwaysErrors checks the
// n > 2f+2 precondition: every input at or below the envelope must be
// rejected, matching multiKrumSelectSafe_none_outside_envelope.
func TestMultiKrumSelect_Property_BelowEnvelopeAlwaysErrors(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		f := rng.IntN(6) // 0..5
		envelope := 2*f + 2
		n := rng.IntN(envelope + 1) // 0..envelope, i.e. n <= 2f+2
		dim := 1 + rng.IntN(4)
		updates := randGradients(rng, n, dim)

		_, _, err := MultiKrumSelect(updates, f, 0)
		if err == nil {
			t.Fatalf("trial %d: expected error for n=%d f=%d (envelope n>2f+2=%d), got none", trial, n, f, envelope)
		}
	}
}

// TestMultiKrumSelect_Property_AboveEnvelopeSatisfiesPostconditions checks
// the postconditions already stated in MultiKrumSelect's own @ensures
// comments across many random valid inputs: success, non-empty selection,
// selection bounded by n, every selected index in range, and no duplicate
// indices (selection is drawn from a permutation of 0..n-1 by construction).
func TestMultiKrumSelect_Property_AboveEnvelopeSatisfiesPostconditions(t *testing.T) {
	rng := rand.New(rand.NewPCG(2, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		f := rng.IntN(6)
		envelope := 2*f + 2
		n := envelope + 1 + rng.IntN(15) // always > 2f+2
		dim := 1 + rng.IntN(4)
		updates := randGradients(rng, n, dim)

		// m=0 exercises the default (neighbors = n-f-2); a random m in
		// (0,n] exercises the general-m path closed by PR #162; a random
		// m > n exercises the "m clamped to n" branch.
		m := 0
		switch rng.IntN(3) {
		case 1:
			m = 1 + rng.IntN(n)
		case 2:
			m = n + 1 + rng.IntN(10)
		}

		selected, scores, err := MultiKrumSelect(updates, f, m)
		if err != nil {
			t.Fatalf("trial %d: unexpected error for n=%d f=%d m=%d: %v", trial, n, f, m, err)
		}
		if len(scores) != n {
			t.Fatalf("trial %d: len(scores)=%d, want %d", trial, len(scores), n)
		}
		if len(selected) == 0 {
			t.Fatalf("trial %d: selected is empty, want 0 < len(selected)", trial)
		}
		if len(selected) > n {
			t.Fatalf("trial %d: len(selected)=%d exceeds n=%d", trial, len(selected), n)
		}

		wantCount := m
		if m <= 0 {
			wantCount = n - f - 2
		} else if m > n {
			wantCount = n
		}
		if len(selected) != wantCount {
			t.Fatalf("trial %d: len(selected)=%d, want %d (n=%d f=%d m=%d)", trial, len(selected), wantCount, n, f, m)
		}

		seen := make(map[int]bool, len(selected))
		for _, idx := range selected {
			if idx < 0 || idx >= n {
				t.Fatalf("trial %d: selected index %d out of range [0,%d)", trial, idx, n)
			}
			if seen[idx] {
				t.Fatalf("trial %d: duplicate selected index %d", trial, idx)
			}
			seen[idx] = true
		}
	}
}

// TestMultiKrumSelect_Property_Deterministic checks that MultiKrumSelect is
// a pure function of its inputs: calling it twice on independent copies of
// the same data must produce identical selections and scores. This is a
// regression net against any future refactor that introduces map-iteration
// or goroutine-order nondeterminism into the selection path.
func TestMultiKrumSelect_Property_Deterministic(t *testing.T) {
	rng := rand.New(rand.NewPCG(3, 0))
	const trials = 100
	for trial := 0; trial < trials; trial++ {
		f := rng.IntN(6)
		envelope := 2*f + 2
		n := envelope + 1 + rng.IntN(15)
		dim := 1 + rng.IntN(4)
		updates := randGradients(rng, n, dim)

		selectedA, scoresA, errA := MultiKrumSelect(cloneGradients(updates), f, 0)
		selectedB, scoresB, errB := MultiKrumSelect(cloneGradients(updates), f, 0)
		if errA != nil || errB != nil {
			t.Fatalf("trial %d: unexpected error errA=%v errB=%v", trial, errA, errB)
		}
		if len(selectedA) != len(selectedB) {
			t.Fatalf("trial %d: selection length differs: %d vs %d", trial, len(selectedA), len(selectedB))
		}
		for i := range selectedA {
			if selectedA[i] != selectedB[i] {
				t.Fatalf("trial %d: selection[%d] differs: %d vs %d", trial, i, selectedA[i], selectedB[i])
			}
		}
		for i := range scoresA {
			if scoresA[i] != scoresB[i] {
				t.Fatalf("trial %d: scores[%d] differs: %v vs %v", trial, i, scoresA[i], scoresB[i])
			}
		}
	}
}
