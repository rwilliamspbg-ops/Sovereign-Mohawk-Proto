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

import (
	"bufio"
	"bytes"
	"encoding/json"
	"testing"
)

func newTracedSimulator(t *testing.T) (*Simulator, *bytes.Buffer) {
	t.Helper()
	var buf bytes.Buffer
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      TopologyConfig{Tiers: 2, CommitteesPerTier: 3, NodesPerCommittee: 27},
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     3,
		Seed:          5,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}
	sim.TraceSink = &buf
	return sim, &buf
}

func TestSimulator_NilTraceSinkEmitsNothing(t *testing.T) {
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      testTopology(),
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     4,
		Seed:          1,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}
	// TraceSink left nil (default).
	if _, err := sim.RunRound(); err != nil {
		t.Fatalf("RunRound failed: %v", err)
	}
	// Nothing to assert on output directly since there's no sink -- the
	// real assertion is that RunRound didn't panic/error with a nil sink,
	// confirming writeTrace's nil-check is exercised on the hot path.
}

func TestSimulator_TraceEventShapeAndOrder(t *testing.T) {
	sim, buf := newTracedSimulator(t)
	if _, err := sim.RunRound(); err != nil {
		t.Fatalf("RunRound failed: %v", err)
	}

	events := parseTraceEvents(t, buf.Bytes())
	if len(events) == 0 {
		t.Fatal("expected at least one traced event")
	}

	if events[0].Event != "round_start" {
		t.Fatalf("expected first event to be round_start, got %s", events[0].Event)
	}
	last := events[len(events)-1]
	if last.Event != "round_summary" || last.RootSafe == nil {
		t.Fatalf("expected last event to be a round_summary with RootSafe set, got %+v", last)
	}

	// Every committee_formed must be immediately followed by a
	// committee_selection for the same committee, and every tier's block
	// of committees must end with exactly one tier_aggregate for that
	// tier before the next tier (or round_summary) begins.
	seenTiers := map[int]bool{}
	for i := 0; i < len(events); i++ {
		ev := events[i]
		switch ev.Event {
		case "committee_formed":
			if i+1 >= len(events) || events[i+1].Event != "committee_selection" {
				t.Fatalf("committee_formed at seq %d not immediately followed by committee_selection", ev.Seq)
			}
			if events[i+1].CommitteeID != ev.CommitteeID {
				t.Fatalf("committee_formed/committee_selection committee_id mismatch: %s vs %s", ev.CommitteeID, events[i+1].CommitteeID)
			}
			if len(ev.MemberLabels) != 27 {
				t.Fatalf("committee_formed: expected 27 member_labels, got %d", len(ev.MemberLabels))
			}
		case "committee_selection":
			if len(ev.Gradients) != 27 {
				t.Fatalf("committee_selection: expected 27 gradients, got %d", len(ev.Gradients))
			}
			if ev.LocallySafe == nil {
				t.Fatalf("committee_selection at seq %d missing locally_safe", ev.Seq)
			}
		case "tier_aggregate":
			if seenTiers[ev.TierID] {
				t.Fatalf("tier_aggregate for tier %d emitted more than once this round", ev.TierID)
			}
			seenTiers[ev.TierID] = true
			if ev.TotalLeaves != 3*27 {
				t.Fatalf("tier %d: expected total_leaves=%d, got %d", ev.TierID, 3*27, ev.TotalLeaves)
			}
		}
	}
	if len(seenTiers) != 2 {
		t.Fatalf("expected tier_aggregate for both of the 2 configured tiers, got %d", len(seenTiers))
	}
}

func TestSimulator_TraceSeqStrictlyIncreasing(t *testing.T) {
	sim, buf := newTracedSimulator(t)
	if _, err := sim.Run(3); err != nil {
		t.Fatalf("Run failed: %v", err)
	}
	events := parseTraceEvents(t, buf.Bytes())
	for i := 1; i < len(events); i++ {
		if events[i].Seq <= events[i-1].Seq {
			t.Fatalf("trace seq not strictly increasing at index %d: %d then %d", i, events[i-1].Seq, events[i].Seq)
		}
	}
}

func parseTraceEvents(t *testing.T, data []byte) []TraceEvent {
	t.Helper()
	var events []TraceEvent
	scanner := bufio.NewScanner(bytes.NewReader(data))
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var ev TraceEvent
		if err := json.Unmarshal(line, &ev); err != nil {
			t.Fatalf("failed to parse traced JSONL line %q: %v", line, err)
		}
		events = append(events, ev)
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("failed scanning trace buffer: %v", err)
	}
	return events
}
