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

// Reference: /proofs/bft_resilience.md
// Supporting verification for Theorem 1 (55.5% Byzantine Tolerance).
package tpm

import (
	"fmt"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
)

// VerifyShardIntegrity ensures that a regional shard has enough participants
// to meet the local f < n/2 requirement.
func VerifyShardIntegrity(participants int, faultyNodes int) error {
	minimumHonest := hva.MinimumHonestNodes(participants)
	honestNodes := participants - faultyNodes
	if honestNodes < minimumHonest {
		return fmt.Errorf("shard security failure: honest=%d requires >= %d to satisfy the 55.5%% Theorem 1 boundary", honestNodes, minimumHonest)
	}
	return nil
}
