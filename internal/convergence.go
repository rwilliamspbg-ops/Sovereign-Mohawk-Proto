// Reference: /proofs/convergence.md
package internal

import (
	"math"
)

// ConvergenceMonitor tracks Theorem 6: Non-IID Convergence Bound.
// It calculates if the current training round is within the expected
// gradient norm bound: O(1/sqrt(KT)) + O(ζ²)
type ConvergenceMonitor struct {
	HeterogeneityBound float64 // ζ²
	LocalSteps          int     // K
	CurrentRound        int     // T
}

// GetExpectedErrorBound returns the theoretical error margin for the current round.
func (cm *ConvergenceMonitor) GetExpectedErrorBound() float64 {
	if cm.CurrentRound == 0 {
		return math.Inf(1)
	}
	
	// Implementation of O(1/sqrt(KT))
	theoreticalRate := 1.0 / math.Sqrt(float64(cm.LocalSteps * cm.CurrentRound))
	
	// Total Bound = Convergence Rate + Heterogeneity Penalty
	return theoreticalRate + cm.HeterogeneityBound
}
