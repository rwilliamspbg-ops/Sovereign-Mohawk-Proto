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

// Reference: /proofs/communication.md
package internal

import (
	"fmt"
	"log"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

// Tier represents the hierarchical level of the aggregator.
// Defined here to ensure visibility across the internal package.
type Tier int

const (
	Regional    Tier = 1
	Continental Tier = 2
	Global      Tier = 3
)

// Aggregator coordinates the verification and synthesis of model updates.
type Aggregator struct {
	Tier        Tier
	Accountant  *RDPAccountant
	Liveness    *StragglerMonitor
	Convergence *ConvergenceMonitor
	MeshPlan    hva.Plan
}

// NewAggregator initializes a tier-specific aggregator with all formal guards.
func NewAggregator(t Tier) *Aggregator {
	totalNodes := 1000
	switch t {
	case Continental:
		totalNodes = 100000
	case Global:
		totalNodes = 10000000
	}

	meshPlan, _ := hva.BuildPlan(totalNodes, 1024)
	return &Aggregator{
		Tier:        t,
		Accountant:  NewRDPAccountant(2.0, 1e-5),
		Liveness:    NewStragglerMonitor(),
		Convergence: NewConvergenceMonitor(0.1, 0.01),
		MeshPlan:    meshPlan,
	}
}

// ProcessUpdates executes the verified aggregation pipeline.
func (a *Aggregator) ProcessUpdates(activeNodes int, totalNodes int, gradNorm float64) error {
	meshPlan, err := hva.BuildPlan(totalNodes, 1024)
	if err != nil {
		return fmt.Errorf("hierarchical mesh planning failed: %w", err)
	}
	a.MeshPlan = meshPlan
	metrics.ObserveHVALevels(fmt.Sprintf("tier-%d", a.Tier), len(meshPlan.Levels))

	// Active Guard: Theorem 4 (Straggler Resilience)
	if err := a.Liveness.ValidateLiveness(activeNodes, totalNodes); err != nil {
		return fmt.Errorf("liveness check failed: %w", err)
	}
	metrics.ObserveConsensus(fmt.Sprintf("tier-%d", a.Tier), activeNodes, totalNodes)

	// Active Guard: Theorem 2 (Privacy Budget)
	if err := a.Accountant.CheckBudget(); err != nil {
		return fmt.Errorf("privacy guard triggered: %w", err)
	}

	// Active Guard: Theorem 6 (Convergence)
	if !a.Convergence.IsConverging(gradNorm) {
		log.Printf("Warning: Non-IID divergence detected at tier %d", a.Tier)
	}

	log.Printf("Tier %d aggregation verified and complete", a.Tier)
	return nil
}
