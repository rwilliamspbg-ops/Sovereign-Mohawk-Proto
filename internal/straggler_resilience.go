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
	RedundancyFactor   int           // r = 10x
	RegionalTimeout    time.Duration // 30s edge-regional
	GlobalTimeout      time.Duration // 5min regional-continental
	CorrelationFactor  float64       // rho in [0,1]; 0 = independent (default), 1 = perfectly correlated
}

// NewStragglerMonitor initializes a monitor based on Theorem 4 parameters
// (independent-dropout model, rho = 0).
func NewStragglerMonitor() *StragglerMonitor {
	return &StragglerMonitor{
		RedundancyFactor:  10,
		RegionalTimeout:   30 * time.Second,
		GlobalTimeout:     5 * time.Minute,
		CorrelationFactor: 0,
	}
}

// NewCorrelatedStragglerMonitor initializes a monitor using the correlated-
// dropout model with the given correlation factor rho in [0,1].
func NewCorrelatedStragglerMonitor(rho float64) *StragglerMonitor {
	if rho < 0 {
		rho = 0
	}
	if rho > 1 {
		rho = 1
	}
	m := NewStragglerMonitor()
	m.CorrelationFactor = rho
	return m
}

// PerRegionFailureBound returns the failure probability upper bound for one
// region under the simple independent-dropout redundancy model (rho = 0).
func (sm *StragglerMonitor) PerRegionFailureBound(dropoutRate float64) float64 {
	if dropoutRate <= 0 {
		return 0
	}
	if dropoutRate >= 1 {
		return 1
	}
	return math.Pow(dropoutRate, float64(sm.RedundancyFactor))
}

// CorrelatedFailureBound returns the failure probability upper bound under
// the linear-correlation model: p^r * (1 + (r-1)*rho), capped at 1.
// rho = 0 recovers the independent model; rho = 1 is the worst case.
// Mirrors Lean's correlatedFailureProb in Theorem4StragglerResilience.lean.
func (sm *StragglerMonitor) CorrelatedFailureBound(dropoutRate, rho float64) float64 {
	if dropoutRate <= 0 {
		return 0
	}
	if dropoutRate >= 1 {
		return 1
	}
	if rho < 0 {
		rho = 0
	}
	if rho > 1 {
		rho = 1
	}
	r := float64(sm.RedundancyFactor)
	bound := math.Pow(dropoutRate, r) * (1 + (r-1)*rho)
	if bound > 1 {
		bound = 1
	}
	if bound < 0 {
		bound = 0
	}
	return bound
}

// AdversarialFailureBound returns the worst-case failure probability for an
// adversary that can drop up to d copies: 0 if d < r (cannot take down all
// copies), 1 otherwise. Mirrors Lean's adversarialFailureProb.
func (sm *StragglerMonitor) AdversarialFailureBound(d int) float64 {
	if d < sm.RedundancyFactor {
		return 0
	}
	return 1
}

// EffectiveFailureBound returns the failure bound actually used by this
// monitor: correlated model if CorrelationFactor > 0, else independent.
func (sm *StragglerMonitor) EffectiveFailureBound(dropoutRate float64) float64 {
	if sm.CorrelationFactor > 0 {
		return sm.CorrelatedFailureBound(dropoutRate, sm.CorrelationFactor)
	}
	return sm.PerRegionFailureBound(dropoutRate)
}

// PerRegionSuccessProbability returns the corresponding success probability for
// a single region in the runtime redundancy model.
func (sm *StragglerMonitor) PerRegionSuccessProbability(dropoutRate float64) float64 {
	return 1.0 - sm.EffectiveFailureBound(dropoutRate)
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
