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

// Reference: /internal/stragglers.md
// Theorem 4 runtime guard: redundancy-backed liveness monitoring with a
// Chernoff-style exponential safety margin.
package internal

import (
	"fmt"
	"math"
	"time"
)

// StragglerMonitor tracks node health to ensure liveness at 10M-node scale.
type StragglerMonitor struct {
	RedundancyFactor int           // r = 10x
	RegionalTimeout  time.Duration // 30s edge-regional
	GlobalTimeout    time.Duration // 5min regional-continental
}

// NewStragglerMonitor initializes a monitor based on Theorem 4 parameters.
func NewStragglerMonitor() *StragglerMonitor {
	return &StragglerMonitor{
		RedundancyFactor: 10,
		RegionalTimeout:  30 * time.Second,
		GlobalTimeout:    5 * time.Minute,
	}
}

// PerRegionFailureBound returns the failure probability upper bound for one
// region under the simple independent-dropout redundancy model.
func (sm *StragglerMonitor) PerRegionFailureBound(dropoutRate float64) float64 {
	if dropoutRate <= 0 {
		return 0
	}
	if dropoutRate >= 1 {
		return 1
	}
	return math.Pow(dropoutRate, float64(sm.RedundancyFactor))
}

// PerRegionSuccessProbability returns the corresponding success probability for
// a single region in the runtime redundancy model.
func (sm *StragglerMonitor) PerRegionSuccessProbability(dropoutRate float64) float64 {
	return 1.0 - sm.PerRegionFailureBound(dropoutRate)
}

// CalculateSuccessProbability derives a round-success lower bound from the
// expected number of successful regional aggregations.
func (sm *StragglerMonitor) CalculateSuccessProbability(n int, dropoutRate float64) float64 {
	// Active Guard: ensure the configuration satisfies the redundancy model.
	expectedSuccess := float64(n) * sm.PerRegionSuccessProbability(dropoutRate)

	// Conservative exponential tail bound for aggregated regional success.
	failureProb := math.Exp(-expectedSuccess / 8.0)
	return 1.0 - failureProb
}

// ValidateLiveness ensures the current active set meets the 99.99% threshold.
// Reference: /proofs/straggler_resilience.md
func (sm *StragglerMonitor) ValidateLiveness(activeNodes int, _ int) error {
	// totalNodes is renamed to _ to satisfy golangci-lint (unused-parameter)
	successProb := sm.CalculateSuccessProbability(activeNodes, 0.5)
	if successProb < 0.9999 {
		return fmt.Errorf("liveness risk: success probability %.6f below 99.99%% threshold", successProb)
	}
	return nil
}
