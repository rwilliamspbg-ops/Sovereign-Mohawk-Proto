package internal

import (
	"errors"
	"flag"
	"fmt"
	"math/rand"
	"sort"
	"testing"
)

// Randomized differential test between Go's real MultiKrumSelect and an
// independent Go transcription of the Lean spec
// (Specification.multiKrumSelectManyImpl / neighborScore / sqDist in
// proofs/Specification/System.lean).
//
// Why a transcription rather than calling Lean: Lean cannot invoke Go and Go
// cannot invoke Lean, so the two sides can only be compared through a shared
// artifact. The pinned `#eval` vectors in multikrum_lean_correspondence_test.go
// are one such artifact, but they cover four hand-picked inputs. This test
// re-derives the spec side independently in Go and compares it against the real
// implementation over thousands of random configurations.
//
// Exactness. Go's squaredL2 uses a 4-way unrolled accumulation, while the Lean
// spec folds sequentially (`(List.zipWith …).foldl (fun acc x => acc + x) 0.0`).
// Those differ in floating-point association, so a comparison on arbitrary
// floats could disagree in the last bit and flip a near-tie. The generator below
// therefore draws gradients from a small integer grid: squared distances and
// their sums are then exactly representable, the two summation orders agree
// bit-for-bit, and any disagreement is a real semantic difference rather than
// rounding noise. Integer grids also make exact score ties common, which
// exercises the lower-index-wins tie-break.

var (
	diffIterations = flag.Int("multikrum-diff-iterations", 2000, "randomized Multi-Krum differential configurations")
	diffSeed       = flag.Int64("multikrum-diff-seed", 20261118, "RNG seed for the Multi-Krum differential test")
)

// specSqDist transcribes Specification.sqDist exactly: a sequential fold in
// index order, NOT Go's unrolled squaredL2.
func specSqDist(a, b []float64) float64 {
	sum := 0.0
	for i := 0; i < len(a) && i < len(b); i++ {
		d := a[i] - b[i]
		sum += d * d
	}
	return sum
}

// specNeighborScore transcribes Specification.neighborScore.
func specNeighborScore(gradients [][]float64, idx, k int) float64 {
	if idx < 0 || idx >= len(gradients) {
		return 0.0
	}
	g := gradients[idx]
	dists := make([]float64, 0, len(gradients))
	for j, h := range gradients {
		if j == idx {
			continue
		}
		dists = append(dists, specSqDist(g, h))
	}
	sort.Float64s(dists)
	if k > len(dists) {
		k = len(dists)
	}
	sum := 0.0
	for _, x := range dists[:k] {
		sum += x
	}
	return sum
}

type specPair struct {
	idx   int
	score float64
}

// specMultiKrumSelectMany transcribes Specification.multiKrumSelectManyImpl with
// Go's precondition and m-handling. Ranking is a stable ascending sort by score,
// which matches sortAscByScore's stable insertion sort; Go's own ranking breaks
// ties by index explicitly, so the two agree.
func specMultiKrumSelectMany(updates [][]float64, f, m int) ([]int, error) {
	n := len(updates)
	if n == 0 {
		return nil, errors.New("multi-krum requires at least one update")
	}
	if f < 0 {
		return nil, errors.New("multi-krum requires non-negative f")
	}
	if n <= 2*f+2 {
		return nil, fmt.Errorf("multi-krum requires n > 2f+2 (n=%d f=%d)", n, f)
	}
	neighbors := n - f - 2
	if neighbors <= 0 {
		return nil, errors.New("invalid multi-krum neighbor count")
	}
	if m <= 0 {
		m = neighbors
	}
	if m > n {
		m = n
	}
	// Lean's internal clamp: Nat.min k (gradients.length - 1). Under the
	// precondition this never fires (Refinement.go_neighbors_no_clamp), but the
	// transcription keeps it so the two sides stay comparable.
	k := neighbors
	if k > n-1 {
		k = n - 1
	}

	scored := make([]specPair, 0, n)
	for i := 0; i < n; i++ {
		scored = append(scored, specPair{idx: i, score: specNeighborScore(updates, i, k)})
	}
	sort.SliceStable(scored, func(a, b int) bool { return scored[a].score < scored[b].score })

	out := make([]int, 0, m)
	for i := 0; i < m; i++ {
		out = append(out, scored[i].idx)
	}
	return out, nil
}

// gridUpdates draws n gradients of the given dimension with integer coordinates
// in [-span, span], so every squared distance and score is exactly representable.
func gridUpdates(rng *rand.Rand, n, dim, span int) [][]float64 {
	out := make([][]float64, n)
	for i := range out {
		out[i] = make([]float64, dim)
		for j := range out[i] {
			out[i][j] = float64(rng.Intn(2*span+1) - span)
		}
	}
	return out
}

func TestMultiKrumSelect_DifferentialAgainstLeanSpec(t *testing.T) {
	rng := rand.New(rand.NewSource(*diffSeed))

	for iter := 0; iter < *diffIterations; iter++ {
		n := 3 + rng.Intn(10) // 3..12
		f := rng.Intn((n - 3) / 2 + 1)
		if n <= 2*f+2 {
			t.Fatalf("iter %d: generator produced n=%d f=%d outside the envelope", iter, n, f)
		}
		dim := 1 + rng.Intn(3)
		span := 1 + rng.Intn(3)
		updates := gridUpdates(rng, n, dim, span)

		// Exercise m <= 0, 1 <= m <= n, and m > n.
		var m int
		switch rng.Intn(4) {
		case 0:
			m = -1
		case 1:
			m = 1 + rng.Intn(n)
		case 2:
			m = n + 1 + rng.Intn(3)
		default:
			m = 1
		}

		want, err := specMultiKrumSelectMany(updates, f, m)
		if err != nil {
			t.Fatalf("iter %d: spec transcription failed (n=%d f=%d m=%d): %v", iter, n, f, m, err)
		}
		got, _, err := MultiKrumSelect(updates, f, m)
		if err != nil {
			t.Fatalf("iter %d: MultiKrumSelect failed (n=%d f=%d m=%d): %v", iter, n, f, m, err)
		}
		if len(got) != len(want) {
			t.Fatalf("iter %d: n=%d f=%d m=%d dim=%d span=%d: len(got)=%d, len(want)=%d\ngot:  %v\nwant: %v\nupdates: %v",
				iter, n, f, m, dim, span, len(got), len(want), got, want, updates)
		}
		for i := range got {
			if got[i] != want[i] {
				t.Fatalf("iter %d: n=%d f=%d m=%d dim=%d span=%d: selected[%d]=%d, want %d\ngot:  %v\nwant: %v\nupdates: %v",
					iter, n, f, m, dim, span, i, got[i], want[i], got, want, updates)
			}
		}
	}
}

// TestMultiKrumSelect_DifferentialTieHeavy hammers the tie-break: dimension 1
// with coordinates in {-1, 0, 1} makes exact score ties the common case, so a
// disagreement in the lower-index-wins rule cannot hide behind distinct scores.
func TestMultiKrumSelect_DifferentialTieHeavy(t *testing.T) {
	rng := rand.New(rand.NewSource(*diffSeed + 1))

	for iter := 0; iter < *diffIterations; iter++ {
		n := 3 + rng.Intn(8)
		f := rng.Intn((n - 3) / 2 + 1)
		updates := gridUpdates(rng, n, 1, 1)
		m := 1 + rng.Intn(n)

		want, err := specMultiKrumSelectMany(updates, f, m)
		if err != nil {
			t.Fatalf("iter %d: spec transcription failed (n=%d f=%d m=%d): %v", iter, n, f, m, err)
		}
		got, _, err := MultiKrumSelect(updates, f, m)
		if err != nil {
			t.Fatalf("iter %d: MultiKrumSelect failed (n=%d f=%d m=%d): %v", iter, n, f, m, err)
		}
		for i := range want {
			if got[i] != want[i] {
				t.Fatalf("iter %d: n=%d f=%d m=%d: selected[%d]=%d, want %d\ngot:  %v\nwant: %v\nupdates: %v",
					iter, n, f, m, i, got[i], want[i], got, want, updates)
			}
		}
	}
}
