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

// Reference: /proofs/convergence.md
// Tracks gradient norm to ensure O(1/ε²) convergence under Non-IID data.
package internal

import (
	"math"
)

// ConvergenceMonitor implements Theorem 6: Hierarchical SGD Convergence.
// It tracks the expected squared gradient norm bounded by O(1/√(KT)) + O(ζ²).
type ConvergenceMonitor struct {
	HeterogeneityBound float64 // ζ² (Price of non-IID data)
	LearningRate       float64 // η
	TotalRounds        int     // T
	LocalSteps         int     // K
}

// NewConvergenceMonitor initializes the monitor with research-backed parameters.
func NewConvergenceMonitor(zetaSq float64, lr float64) *ConvergenceMonitor {
	return &ConvergenceMonitor{
		HeterogeneityBound: zetaSq,
		LearningRate:       lr,
		TotalRounds:        100, // Default base rounds
		LocalSteps:         10,  // Default local steps per round
	}
}

// GetExpectedErrorBound calculates the O(1/√(KT)) + O(ζ²) bound.
func (cm *ConvergenceMonitor) GetExpectedErrorBound() float64 {
	kt := float64(cm.LocalSteps * cm.TotalRounds)
	return (1.0 / math.Sqrt(kt)) + cm.HeterogeneityBound
}

// IsConverging checks if the current gradient norm is within the theoretical bound.
// If the actual gradient norm exceeds the bound by 50%, it signals divergence.
func (cm *ConvergenceMonitor) IsConverging(currentNorm float64) bool {
	bound := cm.GetExpectedErrorBound()
	return currentNorm <= bound*1.5
}
