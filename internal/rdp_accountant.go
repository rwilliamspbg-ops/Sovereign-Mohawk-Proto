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
	"sync"
)

// RDPAccountant tracks cumulative privacy leakage using Rényi Differential Privacy.
// It implements Theorem 2: sequential composition of RDP mechanisms.
type RDPAccountant struct {
	mu           sync.RWMutex
	Alpha        float64 // Rényi divergence order
	TotalEpsilon float64 // Cumulative RDP epsilon
	MaxBudget    float64 // Target (ε, δ)-DP limit (e.g., 2.0)
	TargetDelta  float64 // Fixed delta (e.g., 10⁻⁵)
}

// NewRDPAccountant initializes the accountant with research-backed defaults.
func NewRDPAccountant(maxEpsilon float64, delta float64) *RDPAccountant {
	return &RDPAccountant{
		Alpha:       10.0, // Optimized alpha for hierarchical composition
		MaxBudget:   maxEpsilon,
		TargetDelta: delta,
	}
}

// RecordStep adds the RDP epsilon of a new mechanism to the running sum.
// Reference: /proofs/differential_privacy.md
func (a *RDPAccountant) RecordStep(epsilon float64) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.TotalEpsilon += epsilon
}

// GetCurrentEpsilon converts cumulative RDP to standard (ε, δ)-DP.
// Conversion formula: ε = ε_rdp + log(1/δ) / (α - 1)
func (a *RDPAccountant) GetCurrentEpsilon() float64 {
	a.mu.RLock()
	defer a.mu.RUnlock()

	if a.TotalEpsilon == 0 {
		return 0
	}

	conversion := math.Log(1.0/a.TargetDelta) / (a.Alpha - 1.0)
	return a.TotalEpsilon + conversion
}

// CheckBudget verifies if the system is still within the verified privacy bound.
func (a *RDPAccountant) CheckBudget() error {
	current := a.GetCurrentEpsilon()
	if current > a.MaxBudget {
		return fmt.Errorf("privacy budget exhausted: current ε=%.2f exceeds limit ε=%.2f", current, a.MaxBudget)
	}
	return nil
}
