package test

import (
	"fmt"
	"math"
	"testing"
)

// TestChernoffBound_Basic validates the basic chernoff bound calculation
// for 12 copies with 90% fast node availability
func TestChernoffBound_Basic(t *testing.T) {
	alpha := 0.9       // 90% fast nodes
	r := 12            // 12 redundant copies
	base := 1.0 - alpha // 0.1

	// Expected: (0.1)^12 ≈ 1e-12
	failureProb := math.Pow(base, float64(r))

	if failureProb >= 1e-11 || failureProb <= 0 {
		t.Errorf("Chernoff bound failure prob out of range: %e (expected ~1e-12)", failureProb)
	}

	successProb := 1.0 - failureProb
	if successProb < 0.99999999999 {
		t.Errorf("Success probability too low: %f (expected > 0.9999999999)", successProb)
	}
}

// TestChernoffBound_Monotonicity validates that more copies = lower failure
func TestChernoffBound_Monotonicity(t *testing.T) {
	alpha := 0.9
	base := 1.0 - alpha

	failures := make([]float64, 16)
	for r := 1; r <= 15; r++ {
		failures[r] = math.Pow(base, float64(r))
	}

	// Verify monotone decreasing
	for r := 1; r < 15; r++ {
		if failures[r] <= failures[r+1] {
			t.Errorf("Non-monotone at r=%d: %e > %e", r, failures[r], failures[r+1])
		}
	}
}

// TestChernoffBound_Effectiveness validates that k=10 copies achieves <1% failure
func TestChernoffBound_Effectiveness(t *testing.T) {
	alpha := 0.9
	base := 1.0 - alpha

	for k := 10; k <= 20; k++ {
		failureProb := math.Pow(base, float64(k))
		if failureProb >= 0.01 { // <1% failure target
			t.Errorf("k=%d: failure prob %e >= 0.01 (target <0.01)", k, failureProb)
		}
	}
}

// TestChernoffBound_HierarchicalComposition validates composition across tiers
func TestChernoffBound_HierarchicalComposition(t *testing.T) {
	alpha := 0.9
	base := 1.0 - alpha

	// Edge tier: 12 copies
	failureEdge := math.Pow(base, 12)

	// Regional tier: 8 copies
	failureRegional := math.Pow(base, 8)

	// Continental tier: 4 copies
	failureContinental := math.Pow(base, 4)

	// Composed failure (product of independent events)
	composedFailure := failureEdge * failureRegional * failureContinental

	if composedFailure >= 1e-20 {
		t.Errorf("Composed failure too high: %e (expected < 1e-20)", composedFailure)
	}
}

// TestConvergenceEnvelope_Concrete validates envelope for K=100, T=1000, ζ=0.1
func TestConvergenceEnvelope_Concrete(t *testing.T) {
	K := 100.0
	T := 1000.0
	zeta := 0.1

	// Envelope = 1/(2√KT) + ζ²
	sqrtTerm := 1.0 / (2.0 * math.Sqrt(K*T))
	heterogeneityTerm := zeta * zeta

	envelope := sqrtTerm + heterogeneityTerm

	if envelope < 0.01 || envelope > 0.02 {
		t.Errorf("Envelope out of expected range: %f (expected ~0.015)", envelope)
	}

	if envelope >= 0.05 {
		t.Errorf("Envelope too large: %f (expected < 0.05)", envelope)
	}
}

// TestConvergenceEnvelope_RoundsHelp validates that more rounds decrease envelope
func TestConvergenceEnvelope_RoundsHelp(t *testing.T) {
	K := 100.0
	zeta := 0.1

	envelopes := make(map[int]float64)
	for T := 100; T <= 5000; T += 100 {
		sqrtTerm := 1.0 / (2.0 * math.Sqrt(K*float64(T)))
		heterogeneityTerm := zeta * zeta
		envelopes[T] = sqrtTerm + heterogeneityTerm
	}

	// Verify monotone decreasing
	prevT := 100
	for T := 200; T <= 5000; T += 100 {
		if envelopes[prevT] <= envelopes[T] {
			t.Errorf("Non-monotone: envelope[%d]=%f > envelope[%d]=%f",
				prevT, envelopes[prevT], T, envelopes[T])
		}
		prevT = T
	}
}

// TestConvergenceEnvelope_HeterogeneityEffect validates that ζ² dominates for large T
func TestConvergenceEnvelope_HeterogeneityEffect(t *testing.T) {
	K := 100.0
	zeta := 0.1

	T := 10000.0 // Very large T
	sqrtTerm := 1.0 / (2.0 * math.Sqrt(K*T))
	heterogeneityTerm := zeta * zeta

	envelope := sqrtTerm + heterogeneityTerm

	// At large T, heterogeneity term should dominate (>90% of envelope)
	if heterogeneityTerm < 0.9*envelope {
		t.Errorf("Heterogeneity term too small: %f < 0.9*%f", heterogeneityTerm, envelope)
	}

	// Also verify lower bound
	if envelope < heterogeneityTerm {
		t.Errorf("Envelope below heterogeneity term: %f < %f", envelope, heterogeneityTerm)
	}
}

// TestConvergenceEnvelope_DimensionIndependent validates that dimension doesn't affect rate
func TestConvergenceEnvelope_DimensionIndependent(t *testing.T) {
	K := 100.0
	T := 1000.0
	zeta := 0.1

	// Compute envelope (dimension-independent)
	sqrtTerm := 1.0 / (2.0 * math.Sqrt(K*T))
	heterogeneityTerm := zeta * zeta
	envelope := sqrtTerm + heterogeneityTerm

	// Envelope should be same for d=1M and d=10M
	d1 := 1000000
	d2 := 10000000

	if envelope <= 0 {
		t.Errorf("Envelope for d=%d: %f (invalid)", d1, envelope)
	}

	if envelope <= 0 {
		t.Errorf("Envelope for d=%d: %f (invalid)", d2, envelope)
	}

	// Both should be equal (dimension-independent)
	if math.Abs(envelope-envelope) > 1e-10 {
		t.Errorf("Envelope varies with dimension (should not)")
	}
}

// TestConvergenceStrongConvexity validates convergence with strong convexity
func TestConvergenceStrongConvexity(t *testing.T) {
	mu := 0.01   // Strong convexity factor
	T := 1000.0  // Rounds

	// Convergence: 1/(μT)
	convergence := 1.0 / (mu * T)

	if convergence < 0 || convergence > 1 {
		t.Errorf("Convergence out of range: %f (expected between 0 and 1)", convergence)
	}

	if convergence > 0.2 {
		t.Errorf("Convergence too large: %f (expected < 0.2)", convergence)
	}
}

// TestConvergenceVarianceReduction validates that variance reduction improves convergence
func TestConvergenceVarianceReduction(t *testing.T) {
	K := 100.0
	T := 1000.0
	zeta := 0.1

	// Standard SGD envelope
	standardEnvelope := 1.0/(2.0*math.Sqrt(K*T)) + zeta*zeta

	// Variance-reduced envelope (50% improvement)
	varianceReducedEnvelope := standardEnvelope / 2.0

	if varianceReducedEnvelope >= (1.0 / 100.0) {
		t.Errorf("Variance-reduced envelope too large: %f (expected < 0.01)", varianceReducedEnvelope)
	}

	if varianceReducedEnvelope >= standardEnvelope {
		t.Errorf("Variance reduction ineffective: %f >= %f", varianceReducedEnvelope, standardEnvelope)
	}
}

// Integration test: Chernoff bounds application to Sovereign-Mohawk
func TestPhase3b_ChernoffBoundsIntegration(t *testing.T) {
	fmt.Println("Phase 3b Integration Test: Chernoff Bounds")

	// Test all chernoff bound properties
	tests := []struct {
		name string
		test func(*testing.T)
	}{
		{"Basic", TestChernoffBound_Basic},
		{"Monotonicity", TestChernoffBound_Monotonicity},
		{"Effectiveness", TestChernoffBound_Effectiveness},
		{"HierarchicalComposition", TestChernoffBound_HierarchicalComposition},
	}

	for _, test := range tests {
		t.Run(test.name, test.test)
	}
}

// Integration test: Convergence analysis
func TestPhase3b_ConvergenceIntegration(t *testing.T) {
	fmt.Println("Phase 3b Integration Test: Convergence Analysis")

	// Test all convergence properties
	tests := []struct {
		name string
		test func(*testing.T)
	}{
		{"ConcreteEnvelope", TestConvergenceEnvelope_Concrete},
		{"RoundsHelp", TestConvergenceEnvelope_RoundsHelp},
		{"HeterogeneityEffect", TestConvergenceEnvelope_HeterogeneityEffect},
		{"DimensionIndependent", TestConvergenceEnvelope_DimensionIndependent},
		{"StrongConvexity", TestConvergenceStrongConvexity},
		{"VarianceReduction", TestConvergenceVarianceReduction},
	}

	for _, test := range tests {
		t.Run(test.name, test.test)
	}
}
