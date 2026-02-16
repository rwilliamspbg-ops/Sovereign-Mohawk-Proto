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
)

// VerifyShardIntegrity ensures that a regional shard has enough participants
// to meet the local f < n/2 requirement.
func VerifyShardIntegrity(participants int, faultyNodes int) error {
	// Active Guard: Enforce Theorem 1 safety threshold at the shard level.
	if participants <= 2*faultyNodes {
		return fmt.Errorf("shard security failure: f=%d requires n > %d (violated Theorem 1)", faultyNodes, 2*faultyNodes)
	}
	return nil
}
