package internal

import (
	"math/rand/v2"
	"testing"
)

// Property-based regression net for Refinement/Convergence.lean.
// Mirrors convergence_impl_refines_spec, convergence_envelope_rounds_monotone,
// convergence_impl_floor_ge_spec.

func TestConvergence_Property_EnvelopePositiveMatchesSpec(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 0))
	const trials = 300
	for trial := 0; trial < trials; trial++ {
		eps := rng.Float64() * 5
		zetaSq := rng.Float64() * 5
		clients := 1 + rng.IntN(50)
		rounds := 1 + rng.IntN(50)
		c := NewConvergenceMonitor(eps, zetaSq)
		got := c.EnvelopeBound(clients, rounds)
		want := 1.0/(2.0*float64(clients)*float64(rounds)) + zetaSq
		if mathAbs(got-want) > 1e-9 {
			t.Fatalf("trial %d: envelope mismatch got=%v want=%v", trial, got, want)
		}
	}
}

func TestConvergence_Property_EnvelopeNonPositiveFallsBack(t *testing.T) {
	rng := rand.New(rand.NewPCG(2, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		eps := rng.Float64() * 5
		zetaSq := rng.Float64() * 5
		c := NewConvergenceMonitor(eps, zetaSq)
		// at least one non-positive
		clients := rng.IntN(2) // 0 or 1 -> make 0 sometimes
		if rng.Float64() < 0.5 {
			clients = 0
		}
		rounds := 1 + rng.IntN(5)
		if rng.Float64() < 0.5 {
			rounds = 0
		}
		got := c.EnvelopeBound(clients, rounds)
		if clients <= 0 || rounds <= 0 {
			if got != zetaSq {
				t.Fatalf("trial %d: expected floor %v got %v", trial, zetaSq, got)
			}
		}
	}
}

func TestConvergence_Property_EffectiveThresholdAdditive(t *testing.T) {
	rng := rand.New(rand.NewPCG(3, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		eps := rng.Float64() * 5
		zetaSq := rng.Float64() * 5
		c := NewConvergenceMonitor(eps, zetaSq)
		if c.EffectiveThreshold() != eps+zetaSq {
			t.Fatalf("trial %d: effective threshold mismatch", trial)
		}
	}
}

func TestConvergence_Property_IsConvergingConsistent(t *testing.T) {
	rng := rand.New(rand.NewPCG(4, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		eps := rng.Float64() * 5
		zetaSq := rng.Float64() * 5
		c := NewConvergenceMonitor(eps, zetaSq)
		grad := rng.Float64() * 10
		got := c.IsConverging(grad)
		want := grad <= eps+zetaSq
		if got != want {
			t.Fatalf("trial %d: IsConverging mismatch got=%v want=%v", trial, got, want)
		}
	}
}

func TestConvergence_Property_RoundsMonotone(t *testing.T) {
	rng := rand.New(rand.NewPCG(5, 0))
	const trials = 200
	for trial := 0; trial < trials; trial++ {
		eps := rng.Float64() * 5
		zetaSq := rng.Float64() * 5
		c := NewConvergenceMonitor(eps, zetaSq)
		k := 1 + rng.IntN(20)
		t1 := 1 + rng.IntN(10)
		t2 := t1 + rng.IntN(10) + 1
		e1 := c.EnvelopeBound(k, t1)
		e2 := c.EnvelopeBound(k, t2)
		if e2 > e1+1e-12 {
			t.Fatalf("trial %d: envelope not monotone in rounds: %v > %v", trial, e2, e1)
		}
	}
}

func mathAbs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}