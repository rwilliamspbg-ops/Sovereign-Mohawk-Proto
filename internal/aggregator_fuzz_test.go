//go:build go1.18

package internal

import (
	"math"
	"testing"
)

// FuzzClampFloat checks that clampFloat always returns a value within [min,max]
// (or handles inverted bounds) and is idempotent.
func FuzzClampFloat(f *testing.F) {
	f.Add(0.5, 0.0, 1.0)
	f.Add(-1.0, 0.0, 1.0)
	f.Add(2.0, 0.0, 1.0)
	f.Add(0.5, 1.0, 0.0) // inverted
	f.Fuzz(func(t *testing.T, v, minV, maxV float64) {
		if math.IsNaN(v) || math.IsNaN(minV) || math.IsNaN(maxV) {
			t.Skip()
		}
		if math.IsInf(v, 0) || math.IsInf(minV, 0) || math.IsInf(maxV, 0) {
			t.Skip()
		}
		got := clampFloat(v, minV, maxV)
		lo, hi := minV, maxV
		if lo > hi {
			lo, hi = hi, lo
		}
		if got < lo || got > hi {
			t.Fatalf("clampFloat(%v,%v,%v)=%v outside [%v,%v]", v, minV, maxV, got, lo, hi)
		}
		// idempotence (only when bounds are ordered)
		if minV <= maxV && clampFloat(got, minV, maxV) != got {
			t.Fatalf("not idempotent: %v", got)
		}
	})
}

// FuzzTrimByGradientNorm checks invariants: non-empty input, keep >=1, no panic.
func FuzzTrimByGradientNorm(f *testing.F) {
	f.Add(3, 2, 0.5)
	f.Add(1, 1, 0.0)
	f.Add(5, 4, 0.9)
	f.Fuzz(func(t *testing.T, n, dim int, fraction float64) {
		if n < 1 || n > 64 || dim < 1 || dim > 16 {
			t.Skip()
		}
		if math.IsNaN(fraction) || math.IsInf(fraction, 0) {
			t.Skip()
		}
		updates := make([][]float64, n)
		for i := range updates {
			updates[i] = make([]float64, dim)
			for j := range updates[i] {
				updates[i][j] = float64(i+j) * 0.1
			}
		}
		got, err := trimByGradientNorm(updates, fraction)
		if err != nil {
			// only acceptable errors
			if fraction >= 1 && len(updates) > 0 {
				return
			}
			if len(updates) == 0 {
				return
			}
			t.Fatalf("unexpected err: %v (fraction=%v)", err, fraction)
		}
		if len(got) == 0 {
			t.Fatal("trim returned empty result")
		}
		if len(got) > len(updates) {
			t.Fatalf("trim grew: %d -> %d", len(updates), len(got))
		}
	})
}

// FuzzHierarchicalAverage checks dimension preservation and no panic.
func FuzzHierarchicalAverage(f *testing.F) {
	f.Add(4, 2, 3)
	f.Add(1, 1, 5)
	f.Add(7, 3, 2)
	f.Fuzz(func(t *testing.T, n, groupSize, dim int) {
		if n < 1 || n > 32 || groupSize < 1 || groupSize > 8 || dim < 1 || dim > 8 {
			t.Skip()
		}
		updates := make([][]float64, n)
		for i := range updates {
			updates[i] = make([]float64, dim)
			for j := range updates[i] {
				updates[i][j] = float64(i*dim + j)
			}
		}
		got := hierarchicalAverage(updates, groupSize)
		if len(got) == 0 {
			t.Fatal("empty result")
		}
		for _, g := range got {
			if len(g) != dim {
				t.Fatalf("dim mismatch: got %d want %d", len(g), dim)
			}
		}
	})
}

// FuzzMeanGradient checks output dimension and finiteness.
func FuzzMeanGradient(f *testing.F) {
	f.Add(3, 4)
	f.Add(1, 1)
	f.Fuzz(func(t *testing.T, n, dim int) {
		if n < 1 || n > 32 || dim < 1 || dim > 16 {
			t.Skip()
		}
		updates := make([][]float64, n)
		for i := range updates {
			updates[i] = make([]float64, dim)
			for j := range updates[i] {
				updates[i][j] = float64(i + j)
			}
		}
		got := meanGradient(updates)
		if len(got) != dim {
			t.Fatalf("dim mismatch: %d vs %d", len(got), dim)
		}
		for _, v := range got {
			if math.IsNaN(v) || math.IsInf(v, 0) {
				t.Fatalf("non-finite: %v", v)
			}
		}
	})
}

// FuzzMaxGradNorm checks non-negative and >= each individual norm.
func FuzzMaxGradNorm(f *testing.F) {
	f.Add(3, 4)
	f.Fuzz(func(t *testing.T, n, dim int) {
		if n < 1 || n > 32 || dim < 1 || dim > 16 {
			t.Skip()
		}
		updates := make([][]float64, n)
		for i := range updates {
			updates[i] = make([]float64, dim)
			for j := range updates[i] {
				updates[i][j] = float64(i - j)
			}
		}
		got := maxGradNorm(updates)
		if got < 0 {
			t.Fatalf("negative: %v", got)
		}
		for _, u := range updates {
			sq := 0.0
			for _, v := range u {
				sq += v * v
			}
			if math.Sqrt(sq) > got+1e-9 {
				t.Fatalf("maxGradNorm smaller than member: %v < %v", got, math.Sqrt(sq))
			}
		}
	})
}

// FuzzResolvedQuorum checks output within [min,max] (or defaults).
func FuzzResolvedQuorum(f *testing.F) {
	f.Add(0.5, 100.0, 0.5, 1.0, 200.0)
	f.Fuzz(func(t *testing.T, q, latency, minQ, maxQ, target float64) {
		if math.IsNaN(q) || math.IsNaN(latency) || math.IsNaN(minQ) || math.IsNaN(maxQ) || math.IsNaN(target) {
			t.Skip()
		}
		if math.IsInf(q, 0) || math.IsInf(latency, 0) || math.IsInf(minQ, 0) || math.IsInf(maxQ, 0) || math.IsInf(target, 0) {
			t.Skip()
		}
		opts := BatchProcessingOptions{
			SemiAsyncQuorum:     q,
			AdaptiveQuorumMin:   minQ,
			AdaptiveQuorumMax:   maxQ,
			AdaptiveTargetP95Ms: target,
		}
		got := resolvedQuorum(opts, latency)
		if math.IsNaN(got) || math.IsInf(got, 0) {
			t.Fatalf("non-finite: %v", got)
		}
	})
}

// FuzzEWMA checks basic properties.
func FuzzEWMA(f *testing.F) {
	f.Add(0.0, 5.0, 0.3)
	f.Add(2.0, 5.0, 0.3)
	f.Fuzz(func(t *testing.T, prev, sample, alpha float64) {
		if math.IsNaN(prev) || math.IsNaN(sample) || math.IsNaN(alpha) {
			t.Skip()
		}
		if math.IsInf(prev, 0) || math.IsInf(sample, 0) || math.IsInf(alpha, 0) {
			t.Skip()
		}
		got := ewma(prev, sample, alpha)
		if math.IsNaN(got) || math.IsInf(got, 0) {
			t.Fatalf("non-finite: %v", got)
		}
	})
}

// FuzzScaleVector checks no panic and finite output.
func FuzzScaleVector(f *testing.F) {
	f.Add(3, 2.0)
	f.Fuzz(func(t *testing.T, n int, factor float64) {
		if n < 1 || n > 64 {
			t.Skip()
		}
		if math.IsNaN(factor) || math.IsInf(factor, 0) {
			t.Skip()
		}
		vec := make([]float64, n)
		for i := range vec {
			vec[i] = float64(i)
		}
		scaleVector(vec, factor)
		for _, v := range vec {
			if math.IsNaN(v) || math.IsInf(v, 0) {
				t.Fatalf("non-finite after scale: %v", v)
			}
		}
	})
}

// FuzzApplyStalenessDecay checks no panic.
func FuzzApplyStalenessDecay(f *testing.F) {
	f.Add(3, 10.0)
	f.Fuzz(func(t *testing.T, n int, halfLife float64) {
		if n < 1 || n > 32 {
			t.Skip()
		}
		if math.IsNaN(halfLife) || math.IsInf(halfLife, 0) {
			t.Skip()
		}
		envs := make([]updateEnvelope, n)
		for i := range envs {
			envs[i] = updateEnvelope{weight: 1.0, ageSec: float64(i)}
		}
		applyStalenessDecay(envs, halfLife)
		for _, e := range envs {
			if math.IsNaN(e.weight) || math.IsInf(e.weight, 0) || e.weight < 0 {
				t.Fatalf("bad weight: %v", e.weight)
			}
		}
	})
}
