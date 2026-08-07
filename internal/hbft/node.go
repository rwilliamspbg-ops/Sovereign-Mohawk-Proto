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

// Package hbft is a stateful, multi-round hierarchical Multi-Krum
// simulator built for trace-based runtime verification of
// proofs/FORMAL_TRACEABILITY_MATRIX.md row 1. It exists purely to drive
// realistic, evolving inputs into the real production selection algorithm
// (internal.MultiKrumSelect); it does not reimplement or approximate
// selection itself.
package hbft

// NodeID identifies a simulated node. Stable across rounds -- unlike
// scripts/byzantine_10m_validation/main.go, which recreates shards (and
// so node identity) every round, this package treats node identity and
// its ground-truth Byzantine label as persistent state, matching how a
// real deployment's set of participants doesn't get re-rolled each round.
type NodeID uint64

// NodeState is a node's persistent identity and ground-truth label. Real
// production code (internal.MultiKrumSelect) never sees IsByzantine --
// it exists here purely as the simulator's planted ground truth for
// verification. See trace.go (added in a later PR) for how this is
// exposed in the execution trace and why that's safe (verification-only,
// never present when tracing is disabled).
type NodeState struct {
	ID          NodeID
	TierID      int
	IsByzantine bool
}
