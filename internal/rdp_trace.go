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

import "encoding/json"

// TraceEvent is one line of a JSONL execution trace of an RDPAccountant,
// emitted when RDPAccountant.TraceSink is set. See
// proofs/TraceValidator/RDPAccountant.lean for the Lean-side consumer that
// replays these events through the already-proven composeRDP ledger model
// (proofs/Refinement/RDPAccountant.lean) and checks the Go execution
// matches it exactly.
//
// Rational quantities are stringified via (*big.Rat).RatString() rather
// than converted to float64, so the Lean side can compare them exactly --
// the same precision guarantee the four fixed test vectors in
// FORMAL_TRACEABILITY_MATRIX.md row 13 already rely on, just extended to a
// live, dynamic call sequence instead of a handful of pinned scenarios.
//
// ConversionTerm is a snapshot of Go's own log(1/delta)/(alpha-1) term
// (computed via math.Log, not exact rational arithmetic) and is
// informational only: Lean's Real.log is noncomputable, so the Lean
// validator cannot independently re-derive this term and pin it exactly
// the way it can the raw additive ledger. What it can and does check is
// that BudgetOK is the correct conclusion from CumulativeEpsilon +
// ConversionTerm vs MaxBudget -- i.e. that CheckBudget's decision was
// actually computed from the same exact ledger value Lean's ledger replay
// independently arrives at, not a stale or diverged one.
type TraceEvent struct {
	Event             string `json:"event"` // "record_step" | "record_shard_step" | "check_budget"
	Seq               int64  `json:"seq"`
	ShardID           string `json:"shard_id,omitempty"`
	Epsilon           string `json:"epsilon,omitempty"`         // record_step / record_shard_step only
	CumulativeEpsilon string `json:"cumulative_epsilon"`        // TotalEpsilon after this event, exact rational
	MaxBudget         string `json:"max_budget,omitempty"`      // check_budget only
	ConversionTerm    string `json:"conversion_term,omitempty"` // check_budget only; see doc comment above
	BudgetOK          *bool  `json:"budget_ok,omitempty"`       // check_budget only
}

// writeTrace best-effort emits ev as one JSON line to a.TraceSink. Tracing
// must never be able to break accountant behavior: a nil sink is a no-op,
// and marshal/write failures are swallowed rather than propagated.
func (a *RDPAccountant) writeTrace(ev TraceEvent) {
	if a.TraceSink == nil {
		return
	}
	line, err := json.Marshal(ev)
	if err != nil {
		return
	}
	line = append(line, '\n')
	_, _ = a.TraceSink.Write(line)
}
