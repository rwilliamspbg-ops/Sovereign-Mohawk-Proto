package internal

import (
	"math"
	"math/rand/v2"
	"testing"
)

// Property-based regression net for Refinement/Straggler.lean.

func TestStraggler_Property_PerRegionFailureBound(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 0))
	const trials = 300
	for trial := 0; trial < trials; trial++ {
		rho := 0.0
		sm := NewStragglerMonitor()
		p := rng.Float64()
		got := sm.PerRegionFailureBound(p)
		want := math.Pow(p, float64(sm.RedundancyFactor))
		if p <= 0 {
			want = 0
		}
		if p >= 1 {
			want = 1
		}
		if math.Abs(got-want) > 1e-9 {
			t.Fatalf("trial %d: got=%v want=%v", trial, got, want)
		}
		_ = rho
	}
}

func TestStraggler_Property_CorrelatedBoundFormula(t *testing.T) {
	rng := rand.New(rand.NewPCG(2, 0))
	const trials = 300
	for trial := 0; trial < trials; trial++ {
		sm := NewStragglerMonitor()
		p := rng.Float64()
		rho := rng.Float64()
		got := sm.CorrelatedFailureBound(p, rho)
		r := float64(sm.RedundancyFactor)
		raw := math.Pow(p, r) * (1 + (r-1)*rho)
		want := raw
		if raw > 1 {
			want = 1
		}
		if raw < 0 {
			want = 0
		}
		if p <= 0 {
			want = 0
		}
		if p >= 1 {
			want = 1
		}
		if math.Abs(got-want) > 1e-9 {
			t.Fatalf("trial %d: got=%v want=%v", trial, got, want)
		}
	}
}

func TestStraggler_Property_AdversarialBound(t *testing.T) {
	rng := rand.New(rand.NewPCG(3, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		sm := NewStragglerMonitor()
		d := rng.IntN(sm.RedundancyFactor + 3)
		got := sm.AdversarialFailureBound(d)
		want := 0.0
		if d >= sm.RedundancyFactor {
			want = 1.0
		}
		if got != want {
			t.Fatalf("trial %d: got=%v want=%v", trial, got, want)
		}
	}
}

func TestStraggler_Property_IndependentLeCorrelated(t *testing.T) {
	rng := rand.New(rand.NewPCG(4, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		sm := NewStragglerMonitor()
		p := rng.Float64()
		rho := rng.Float64()
		ind := sm.PerRegionFailureBound(p)
		corr := sm.CorrelatedFailureBound(p, rho)
		if ind > corr+1e-12 {
			t.Fatalf("trial %d: independent %v > correlated %v", trial, ind, corr)
		}
	}
}

func TestStraggler_Property_EffectiveBoundSelection(t *testing.T) {
	rng := rand.New(rand.NewPCG(5, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		rho := rng.Float64()
		sm := NewCorrelatedStragglerMonitor(rho)
		p := rng.Float64()
		got := sm.EffectiveFailureBound(p)
		if rho > 0 {
			want := sm.CorrelatedFailureBound(p, rho)
			if got != want {
				t.Fatalf("trial %d: effective should be correlated", trial)
			}
		} else {
			want := sm.PerRegionFailureBound(p)
			if got != want {
				t.Fatalf("trial %d: effective should be independent", trial)
			}
		}
	}
}