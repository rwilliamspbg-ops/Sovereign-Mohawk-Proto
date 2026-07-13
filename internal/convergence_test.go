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

package internal

import (
	"math"
	"testing"
)

// TestEnvelopeBound_EdgeCases verifies the fallback behavior of EnvelopeBound
// when provided with non-positive parameter values (clients or rounds).
func TestEnvelopeBound_EdgeCases(t *testing.T) {
	epsilon := 0.1
	zetaSq := 0.01
	monitor := NewConvergenceMonitor(epsilon, zetaSq)

	tests := []struct {
		name     string
		clients  int
		rounds   int
		expected float64
	}{
		{
			name:     "positive parameters - normal calculation",
			clients:  10,
			rounds:   5,
			expected: 1.0/(2.0*10.0*5.0) + zetaSq, // 0.01 + 0.01 = 0.02
		},
		{
			name:     "zero clients - fallback to heterogeneity",
			clients:  0,
			rounds:   5,
			expected: zetaSq,
		},
		{
			name:     "negative clients - fallback to heterogeneity",
			clients:  -5,
			rounds:   10,
			expected: zetaSq,
		},
		{
			name:     "zero rounds - fallback to heterogeneity",
			clients:  10,
			rounds:   0,
			expected: zetaSq,
		},
		{
			name:     "negative rounds - fallback to heterogeneity",
			clients:  8,
			rounds:   -2,
			expected: zetaSq,
		},
		{
			name:     "both parameters non-positive - fallback to heterogeneity",
			clients:  0,
			rounds:   -1,
			expected: zetaSq,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := monitor.EnvelopeBound(tt.clients, tt.rounds)
			if math.Abs(result-tt.expected) > 1e-9 {
				t.Errorf("EnvelopeBound(%d, %d) = %f, expected %f", tt.clients, tt.rounds, result, tt.expected)
			}
		})
	}
}

// TestConvergenceMonitor_BasicFlow verifies the initialization, EffectiveThreshold,
// IsConverging, and GetHeterogeneityEstimate functionality.
func TestConvergenceMonitor_BasicFlow(t *testing.T) {
	epsilon := 0.15
	zetaSq := 0.05
	monitor := NewConvergenceMonitor(epsilon, zetaSq)

	// Check effective threshold calculation (Threshold + Heterogeneity)
	expectedThreshold := 0.20
	if math.Abs(monitor.EffectiveThreshold()-expectedThreshold) > 1e-9 {
		t.Errorf("EffectiveThreshold() = %f, expected %f", monitor.EffectiveThreshold(), expectedThreshold)
	}

	// Under heterogeneity floor (effective threshold is 0.20)
	// norm <= threshold -> should return true
	if !monitor.IsConverging(0.18) {
		t.Error("IsConverging(0.18) returned false, expected true")
	}

	// norm > threshold -> should return false
	if monitor.IsConverging(0.22) {
		t.Error("IsConverging(0.22) returned true, expected false")
	}

	// Verify history is stored
	if len(monitor.History) != 2 {
		t.Errorf("History length = %d, expected 2", len(monitor.History))
	}

	// Heterogeneity Estimate check
	est := monitor.GetHeterogeneityEstimate()
	if math.Abs(est-zetaSq) > 1e-9 {
		t.Errorf("GetHeterogeneityEstimate() = %f, expected %f", est, zetaSq)
	}
}
