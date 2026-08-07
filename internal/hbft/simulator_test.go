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

import "testing"

func testTopology() TopologyConfig {
	// NodesPerCommittee=27 comfortably satisfies MultiKrumSelect's
	// n > 2f+2 precondition at the hva-derived f=12 (2f+2=26 < 27).
	return TopologyConfig{Tiers: 3, CommitteesPerTier: 6, NodesPerCommittee: 27}
}

func TestNewSimulator_RejectsUnsafeTopology(t *testing.T) {
	// NodesPerCommittee=18 yields f=8 via hva.MaximumByzantineNodes,
	// 2f+2=18, violating MultiKrumSelect's n > 2f+2 precondition.
	_, err := NewSimulator(SimulatorConfig{
		Topology:      TopologyConfig{Tiers: 1, CommitteesPerTier: 1, NodesPerCommittee: 18},
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     4,
		Seed:          1,
	})
	if err == nil {
		t.Fatal("expected NewSimulator to reject a topology violating MultiKrumSelect's n > 2f+2 precondition")
	}
}

func TestSimulator_RunRound_CallsRealMultiKrumSelect(t *testing.T) {
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      testTopology(),
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     4,
		Seed:          42,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}

	result, err := sim.RunRound()
	if err != nil {
		t.Fatalf("RunRound failed: %v", err)
	}

	if len(result.Tiers) != 3 {
		t.Fatalf("expected 3 tiers, got %d", len(result.Tiers))
	}
	for _, tier := range result.Tiers {
		if len(tier.Committees) != 6 {
			t.Fatalf("tier %d: expected 6 committees, got %d", tier.TierID, len(tier.Committees))
		}
		for _, c := range tier.Committees {
			if len(c.Committee.Members) != 27 {
				t.Fatalf("committee %s: expected 27 members, got %d", c.Committee.ID, len(c.Committee.Members))
			}
			if len(c.SelectedIdx) == 0 {
				t.Fatalf("committee %s: MultiKrumSelect returned no selected indices", c.Committee.ID)
			}
			for _, idx := range c.SelectedIdx {
				if idx < 0 || idx >= len(c.Committee.Members) {
					t.Fatalf("committee %s: selected index %d out of range", c.Committee.ID, idx)
				}
			}
		}
	}

	// With an outlier adversary at Magnitude=100 far from the honest
	// cluster's ~1.0 centroid, real MultiKrumSelect should exclude
	// Byzantine members from every committee's selection -- this is the
	// actual production algorithm doing real filtering, not a stub.
	for _, tier := range result.Tiers {
		for _, c := range tier.Committees {
			for _, idx := range c.SelectedIdx {
				if c.Labels[idx] {
					t.Fatalf("committee %s: MultiKrumSelect selected a labeled-Byzantine outlier at index %d", c.Committee.ID, idx)
				}
			}
		}
	}
}

func TestSimulator_CommitteeMembershipResamplesEachRound(t *testing.T) {
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      testTopology(),
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     4,
		Seed:          7,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}

	r1, err := sim.RunRound()
	if err != nil {
		t.Fatalf("round 1 failed: %v", err)
	}
	r2, err := sim.RunRound()
	if err != nil {
		t.Fatalf("round 2 failed: %v", err)
	}

	same := true
	for i := range r1.Tiers[0].Committees[0].Committee.Members {
		if r1.Tiers[0].Committees[0].Committee.Members[i] != r2.Tiers[0].Committees[0].Committee.Members[i] {
			same = false
			break
		}
	}
	if same {
		t.Fatal("expected committee membership to differ across rounds (resampled each round), but round 1 and round 2 committee 0 were identical")
	}
}

func TestSimulator_DeterministicGivenSeed(t *testing.T) {
	cfg := SimulatorConfig{
		Topology:      testTopology(),
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     4,
		Seed:          123,
	}

	simA, err := NewSimulator(cfg)
	if err != nil {
		t.Fatalf("NewSimulator (A) failed: %v", err)
	}
	simB, err := NewSimulator(cfg)
	if err != nil {
		t.Fatalf("NewSimulator (B) failed: %v", err)
	}

	rounds, err := simA.Run(3)
	if err != nil {
		t.Fatalf("simA.Run failed: %v", err)
	}
	roundsB, err := simB.Run(3)
	if err != nil {
		t.Fatalf("simB.Run failed: %v", err)
	}

	if len(rounds) != len(roundsB) {
		t.Fatalf("round count mismatch: %d vs %d", len(rounds), len(roundsB))
	}
	for i := range rounds {
		a, b := rounds[i], roundsB[i]
		if a.RootSafe != b.RootSafe {
			t.Fatalf("round %d: RootSafe mismatch between identically-seeded runs: %v vs %v", i, a.RootSafe, b.RootSafe)
		}
		for ti := range a.Tiers {
			if a.Tiers[ti].SafeLeafWeight != b.Tiers[ti].SafeLeafWeight {
				t.Fatalf("round %d tier %d: SafeLeafWeight mismatch between identically-seeded runs: %d vs %d",
					i, ti, a.Tiers[ti].SafeLeafWeight, b.Tiers[ti].SafeLeafWeight)
			}
			for ci := range a.Tiers[ti].Committees {
				ca, cb := a.Tiers[ti].Committees[ci], b.Tiers[ti].Committees[ci]
				if len(ca.Committee.Members) != len(cb.Committee.Members) {
					t.Fatalf("round %d tier %d committee %d: member count mismatch", i, ti, ci)
				}
				for mi := range ca.Committee.Members {
					if ca.Committee.Members[mi] != cb.Committee.Members[mi] {
						t.Fatalf("round %d tier %d committee %d: member %d differs between identically-seeded runs", i, ti, ci, mi)
					}
				}
			}
		}
	}
}

func TestSimulator_CollusionAdversary(t *testing.T) {
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      testTopology(),
		ByzantineRate: 0.2,
		Adversary:     CollusionAdversary{Bias: 5.0},
		Dimension:     4,
		Seed:          99,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}

	result, err := sim.RunRound()
	if err != nil {
		t.Fatalf("RunRound failed: %v", err)
	}
	if len(result.Tiers) == 0 {
		t.Fatal("expected at least one tier")
	}
	// Just confirm the run completes and produces well-formed output --
	// unlike the far-outlier case, collusion at a moderate bias isn't
	// guaranteed to always be filtered, and that's the point (it's the
	// interesting case, not something this test should assert away).
}
