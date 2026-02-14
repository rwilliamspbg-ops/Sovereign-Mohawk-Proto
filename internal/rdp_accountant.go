package internal

import (
	"fmt"
	"math"
)

// RDPAccountant implements Theorem 2: Rényi Differential Privacy Composition.
// It tracks the cumulative privacy loss across the 4-tier architecture.
// Reference: /proofs/differential_privacy.md
type RDPAccountant struct {
	Alpha        float64 // Rényi order (typically α=10)
	TotalEpsilon float64 // Cumulative RDP ε
	Delta        float64 // Target δ (typically 10⁻⁵)
}

// NewAccountant initializes the tracker with standard Mohawk parameters.
func NewAccountant() *RDPAccountant {
	return &RDPAccountant{
		Alpha: 10.0,
		Delta: 1e-5,
	}
}

// AddPrivacyCost adds the cost of a training round at a specific tier.
// Based on the proof, RDP composes by simple summation.
func (ra *RDPAccountant) AddPrivacyCost(epsilon float64) {
	ra.TotalEpsilon += epsilon
}

// GetStandardEpsilon converts RDP (α, ε_rdp) to standard (ε, δ)-DP.
// Formula: ε = ε_rdp + log(1/δ) / (α - 1)
func (ra *RDPAccountant) GetStandardEpsilon() float64 {
	conversionFactor := math.Log(1/ra.Delta) / (ra.Alpha - 1)
	return ra.TotalEpsilon + conversionFactor
}

// CheckBudget verifies if the system is still under the ε=2.0 limit.
func (ra *RDPAccountant) CheckBudget(limit float64) error {
	current := ra.GetStandardEpsilon()
	if current > limit {
		return fmt.Errorf("privacy budget exhausted: current ε=%.2f, limit=%.2f", current, limit)
	}
	return nil
}
