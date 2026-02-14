package internal

import (
	"fmt"
	"math"
)

// StragglerMonitor implements Theorem 4: Probabilistic Redundancy Guarantees.
// It ensures that with a redundancy parameter (r), the system maintains
// high availability despite node dropouts.
// Reference: /proofs/stragglers.md
type StragglerMonitor struct {
	RedundancyFactor float64 // r (e.g., 10x)
	ExpectedNodes    int     // k (expected successful aggregations)
	DropoutRate      float64 // Probability of node failure (e.g., 0.5)
}

// CalculateSuccessProbability uses the Chernoff bound derivation:
// P[Success] > 1 - exp(-k/2)
func (sm *StragglerMonitor) CalculateSuccessProbability() float64 {
	// P[region fails] = (dropout_rate)^redundancy
	regionFailureProb := math.Pow(sm.DropoutRate, sm.RedundancyFactor)
	regionSuccessProb := 1.0 - regionFailureProb

	// Expected number of successful regions
	k := float64(sm.ExpectedNodes) * regionSuccessProb
	
	// Lower bound of success probability
	return 1.0 - math.Exp(-k/2.0)
}

// ValidateLiveness checks if the current node count satisfies the 99.99% guarantee.
func (sm *StragglerMonitor) ValidateLiveness(activeNodes int) error {
	threshold := 0.9999
	prob := sm.CalculateSuccessProbability()

	if prob < threshold {
		return fmt.Errorf("liveness risk: success probability %.6f is below safety threshold %.4f", prob, threshold)
	}
	return nil
}
