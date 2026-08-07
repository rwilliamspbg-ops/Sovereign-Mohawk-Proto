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

package hbft

// TopologyConfig describes the static shape of the hierarchy: how many
// tiers, how many committees per tier, and how many nodes per committee.
// Node *identity* within that shape is fixed for the whole simulation
// (see Simulator.nodes); committee *membership* is resampled every round
// (see Simulator.RunRound) -- matching the i.i.d.-per-round committee
// sampling proofs/LeanFormalization/Theorem4ChernoffBounds.lean's tail
// bound assumes, not a fixed static partition.
//
// Tiers are independent, parallel groups of committees over their own
// disjoint node sub-pool -- not a nested aggregation pipeline where a
// higher tier processes a lower tier's output. proofs/TraceValidator/
// HierarchicalBFT.lean's CommitteeOutcome/TierAccumulator design (see the
// implementation plan) treats every committee, at every tier, uniformly
// as one independent group of leaf-level, ground-truth-labeled nodes --
// "a committee plays the role one HTree.leaf-bearing subtree does" -- so
// a real recursive multi-level aggregation pipeline (higher tiers
// processing lower tiers' aggregate outputs) isn't what this simulator
// needs to build, and inventing one would be an arbitrary design choice
// with no existing spec to ground it in. Multiple tiers exist here purely
// to exercise the same committee-safety mechanic at multiple independent
// scales in a single run, not to model a literal aggregation hierarchy.
type TopologyConfig struct {
	Tiers             int
	CommitteesPerTier int
	NodesPerCommittee int
}

// TotalNodes is the total simulated population size implied by cfg: each
// tier gets its own disjoint sub-pool of CommitteesPerTier *
// NodesPerCommittee nodes.
func (cfg TopologyConfig) TotalNodes() int {
	return cfg.Tiers * cfg.CommitteesPerTier * cfg.NodesPerCommittee
}

// Committee is one committee's realized membership for a single round.
type Committee struct {
	ID      string
	TierID  int
	Members []NodeID
}

// Tier is one round's realized set of committees for a given tier.
type Tier struct {
	ID         int
	Committees []Committee
}
