// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Reference: /proofs/differential_privacy.md
// Theorem 2: Real-time Rényi DP privacy loss tracking with automatic enforcement.
package internal

import (
	"fmt"
	"math"
	"math/big"
	"sync"
)

// RDPAccountant tracks cumulative privacy leakage using Rényi Differential Privacy.
// It implements Theorem 2: sequential composition of RDP mechanisms.
type RDPAccountant struct {
	mu           sync.RWMutex
	Alpha        float64  // Rényi divergence order
	TotalEpsilon *big.Rat // Cumulative RDP epsilon
	MaxBudget    *big.Rat // Target (ε, δ)-DP limit (e.g., 2.0)
	TargetDelta  float64  // Fixed delta (e.g., 10⁻⁵)
}

// NewRDPAccountant initializes the accountant with research-backed defaults.
func NewRDPAccountant(maxEpsilon float64, delta float64) *RDPAccountant {
	maxBudget := new(big.Rat)
	if maxBudget.SetFloat64(maxEpsilon) == nil {
		maxBudget = new(big.Rat)
	}
	return &RDPAccountant{
		Alpha:        10.0, // Optimized alpha for hierarchical composition
		TotalEpsilon: new(big.Rat),
		MaxBudget:    maxBudget,
		TargetDelta:  delta,
	}
}

// RecordStep adds the RDP epsilon of a new mechanism to the running sum.
// Reference: /proofs/differential_privacy.md
func (a *RDPAccountant) RecordStep(epsilon float64) {
	rat := ratFromFloat64(epsilon)
	a.RecordStepRat(rat)
}

// RecordStepRat adds the RDP epsilon using rational arithmetic to avoid
// cumulative floating-point drift across many composition steps.
func (a *RDPAccountant) RecordStepRat(epsilon *big.Rat) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if epsilon == nil {
		return
	}
	a.TotalEpsilon.Add(a.TotalEpsilon, epsilon)
}

// RecordGaussianStepRDP records one Gaussian mechanism step using the standard
// RDP composition formula epsilon(alpha) = alpha/(2*sigma^2).
func (a *RDPAccountant) RecordGaussianStepRDP(sigma float64) error {
	if sigma <= 0 {
		return fmt.Errorf("sigma must be positive")
	}
	epsilon := a.Alpha / (2.0 * sigma * sigma)
	a.RecordStep(epsilon)
	return nil
}

// GetCurrentEpsilon converts cumulative RDP to standard (ε, δ)-DP.
// Conversion formula: ε = ε_rdp + log(1/δ) / (α - 1)
func (a *RDPAccountant) GetCurrentEpsilon() float64 {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.TotalEpsilon.Sign() == 0 {
		return 0
	}

	conversion := math.Log(1.0/a.TargetDelta) / (a.Alpha - 1.0)
	total, _ := a.TotalEpsilon.Float64()
	return total + conversion
}

// GetCurrentEpsilonRat returns the current epsilon as a rational value derived
// from the rational ledger plus the converted (epsilon, delta) term.
func (a *RDPAccountant) GetCurrentEpsilonRat() *big.Rat {
	a.mu.RLock()
	defer a.mu.RUnlock()
	if a.TotalEpsilon.Sign() == 0 {
		return new(big.Rat)
	}
	conversion := math.Log(1.0/a.TargetDelta) / (a.Alpha - 1.0)
	current := new(big.Rat).Set(a.TotalEpsilon)
	current.Add(current, ratFromFloat64(conversion))
	return current
}

// MaxBudgetFloat returns the configured epsilon budget as float64 for callers
// that need stable formatting/logging.
func (a *RDPAccountant) MaxBudgetFloat() float64 {
	a.mu.RLock()
	defer a.mu.RUnlock()
	if a.MaxBudget == nil {
		return 0
	}
	v, _ := a.MaxBudget.Float64()
	return v
}

// CheckBudget verifies if the system is still within the verified privacy bound.
func (a *RDPAccountant) CheckBudget() error {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.TotalEpsilon.Sign() == 0 {
		return nil
	}

	conversion := math.Log(1.0/a.TargetDelta) / (a.Alpha - 1.0)
	current := new(big.Rat).Set(a.TotalEpsilon)
	current.Add(current, ratFromFloat64(conversion))
	if current.Cmp(a.MaxBudget) > 0 {
		currentFloat, _ := current.Float64()
		maxFloat, _ := a.MaxBudget.Float64()
		return fmt.Errorf("privacy budget exhausted: current ε=%.2f exceeds limit ε=%.2f", currentFloat, maxFloat)
	}
	return nil
}

func ratFromFloat64(v float64) *big.Rat {
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return new(big.Rat)
	}
	return new(big.Rat).SetFloat64(v)
}
