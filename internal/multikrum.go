package internal

import (
	"fmt"
	"math"
	"sort"
)

// MultiKrumSelect returns the selected update indices and Krum scores.
//
// n: number of updates
// f: Byzantine upper bound
// m: number of selected updates (if <= 0 defaults to n-f-2)
func MultiKrumSelect(updates [][]float64, f int, m int) ([]int, []float64, error) {
	n := len(updates)
	if n == 0 {
		return nil, nil, fmt.Errorf("multi-krum requires at least one update")
	}
	if f < 0 {
		return nil, nil, fmt.Errorf("multi-krum requires non-negative f")
	}
	if n <= 2*f+2 {
		return nil, nil, fmt.Errorf("multi-krum requires n > 2f+2 (n=%d f=%d)", n, f)
	}
	dim := len(updates[0])
	for i := 1; i < n; i++ {
		if len(updates[i]) != dim {
			return nil, nil, fmt.Errorf("gradient %d dimension %d != %d", i, len(updates[i]), dim)
		}
	}

	neighbors := n - f - 2
	if neighbors <= 0 {
		return nil, nil, fmt.Errorf("invalid multi-krum neighbor count")
	}
	if m <= 0 {
		m = neighbors
	}
	if m > n {
		m = n
	}

	// Build a full pairwise distance matrix once, then reuse for per-row Krum scores.
	distMatrix := make([][]float64, n)
	for i := 0; i < n; i++ {
		distMatrix[i] = make([]float64, n)
	}
	for i := 0; i < n; i++ {
		for j := i + 1; j < n; j++ {
			d := squaredL2(updates[i], updates[j])
			distMatrix[i][j] = d
			distMatrix[j][i] = d
		}
	}

	scores := make([]float64, n)
	for i := 0; i < n; i++ {
		row := make([]float64, 0, n-1)
		for j := 0; j < n; j++ {
			if j == i {
				continue
			}
			row = append(row, distMatrix[i][j])
		}
		sort.Float64s(row)
		sum := 0.0
		for k := 0; k < neighbors; k++ {
			sum += row[k]
		}
		scores[i] = sum
	}

	type scoredIndex struct {
		idx   int
		score float64
	}
	ranked := make([]scoredIndex, 0, n)
	for i, s := range scores {
		ranked = append(ranked, scoredIndex{idx: i, score: s})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].score == ranked[j].score {
			return ranked[i].idx < ranked[j].idx
		}
		return ranked[i].score < ranked[j].score
	})

	selected := make([]int, 0, m)
	for i := 0; i < m; i++ {
		selected = append(selected, ranked[i].idx)
	}
	return selected, scores, nil
}

// MultiKrumAggregate computes the elementwise mean of selected updates.
func MultiKrumAggregate(updates [][]float64, f int, m int) ([]float64, []int, []float64, error) {
	selected, scores, err := MultiKrumSelect(updates, f, m)
	if err != nil {
		return nil, nil, nil, err
	}
	dim := len(updates[0])
	mean := make([]float64, dim)
	for _, idx := range selected {
		accumulateFloat64Unrolled(mean, updates[idx])
	}
	scale := 1.0 / float64(len(selected))
	for i := range mean {
		mean[i] *= scale
	}
	return mean, selected, scores, nil
}

func squaredL2(a []float64, b []float64) float64 {
	sum := 0.0
	i := 0
	for ; i+3 < len(a); i += 4 {
		d0 := a[i] - b[i]
		d1 := a[i+1] - b[i+1]
		d2 := a[i+2] - b[i+2]
		d3 := a[i+3] - b[i+3]
		sum += d0*d0 + d1*d1 + d2*d2 + d3*d3
	}
	for ; i < len(a); i++ {
		d := a[i] - b[i]
		sum += d * d
	}
	if math.IsNaN(sum) || math.IsInf(sum, 0) {
		return math.MaxFloat64
	}
	return sum
}

func accumulateFloat64Unrolled(dst []float64, src []float64) {
	i := 0
	for ; i+3 < len(dst); i += 4 {
		dst[i] += src[i]
		dst[i+1] += src[i+1]
		dst[i+2] += src[i+2]
		dst[i+3] += src[i+3]
	}
	for ; i < len(dst); i++ {
		dst[i] += src[i]
	}
}
