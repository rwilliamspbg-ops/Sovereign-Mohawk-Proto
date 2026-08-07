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

import "encoding/json"

// TraceEvent is one line of a JSONL execution trace of a Simulator run,
// emitted when Simulator.TraceSink is set. See
// proofs/TraceValidator/HierarchicalBFT.lean (added in a later PR) for the
// Lean-side consumer that replays these events through a model reusing
// proofs/LeanFormalization/Theorem1BFT.lean's HTree.safe weighted-credit
// rule and independently re-runs Multi-Krum selection on the recorded
// Gradients, cross-checking against SelectedIdx.
//
// MemberLabels is ground truth planted by the simulator (see node.go) --
// internal.MultiKrumSelect never sees it, only Gradients. It exists in
// the trace purely as the verification-only ground truth a structural
// replay needs, exactly the way the RDP accountant's trace exposed
// TotalEpsilon in full even though a production caller might not always
// read it back. It is only ever present when TraceSink is explicitly set
// (never in a production path, since nothing in this repo's production
// code sets it).
// Numeric fields shared across multiple event types (TierID, ByzantineF,
// TotalLeaves, ByzantineLeaves, SafeLeafWeight) are deliberately NOT
// `omitempty`: Go's encoding/json omits a struct field under `omitempty`
// whenever it equals that type's zero value, and 0 is a real, legitimate
// value for every one of these fields (tier 0 is a real tier; a fully
// honest committee has ByzantineF-relevant counts of 0). Omitting them
// would make "field is genuinely 0" indistinguishable from "field does
// not apply to this event type" on the Lean-side parser -- caught during
// this PR's own testing (tier 0's committee_formed/committee_selection
// events were silently missing tier_id entirely). Booleans use the same
// *bool-pointer fix already applied (LocallySafe, RootSafe): `false` is
// equally a real value `omitempty` would otherwise conflate with absence.
type TraceEvent struct {
	Event string `json:"event"` // round_start|committee_formed|committee_selection|tier_aggregate|round_summary
	Seq   int64  `json:"seq"`
	Round int    `json:"round"`

	Seed uint64 `json:"seed,omitempty"` // round_start only

	CommitteeID string `json:"committee_id,omitempty"` // committee_formed, committee_selection; empty string never a real committee ID
	TierID      int    `json:"tier_id"`                // committee_formed, committee_selection, tier_aggregate

	Members      []uint64 `json:"members,omitempty"`       // committee_formed only
	MemberLabels []bool   `json:"member_labels,omitempty"` // committee_formed only; ground truth, see doc comment above

	ByzantineF  int         `json:"byzantine_f"`            // committee_selection only
	Gradients   [][]float64 `json:"gradients,omitempty"`    // committee_selection only
	SelectedIdx []int       `json:"selected_idx,omitempty"` // committee_selection only
	LocallySafe *bool       `json:"locally_safe,omitempty"` // committee_selection only

	// tier_aggregate only: this round's totals for TierID after folding
	// in all of that tier's committees this round (not accumulated
	// across rounds -- each round's tier_aggregate is a fresh count).
	TotalLeaves     int `json:"total_leaves"`
	ByzantineLeaves int `json:"byzantine_leaves"`
	SafeLeafWeight  int `json:"safe_leaf_weight"`

	RootSafe *bool `json:"root_safe,omitempty"` // round_summary only
}

// writeTrace best-effort emits ev as one JSON line to s.TraceSink. Tracing
// must never be able to break simulator behavior: a nil sink is a no-op,
// and marshal/write failures are swallowed rather than propagated.
func (s *Simulator) writeTrace(ev TraceEvent) {
	if s.TraceSink == nil {
		return
	}
	line, err := json.Marshal(ev)
	if err != nil {
		return
	}
	line = append(line, '\n')
	_, _ = s.TraceSink.Write(line)
}
