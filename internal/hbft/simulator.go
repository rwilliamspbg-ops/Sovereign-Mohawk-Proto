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
	"fmt"
	"io"
	"math/rand/v2"
	"sync/atomic"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
)

// SimulatorConfig configures a Simulator run.
type SimulatorConfig struct {
	Topology      TopologyConfig
	ByzantineRate float64 // fraction of each tier's node pool marked Byzantine at construction (ground truth, fixed for the run)
	Adversary     AdversaryStrategy
	Dimension     int
	Seed          uint64
}

// CommitteeResult is one committee's realized outcome for one round.
type CommitteeResult struct {
	Committee Committee
	// Labels is ground truth (same order as Committee.Members), never
	// seen by internal.MultiKrumSelect itself -- see node.go.
	Labels      []bool
	Gradients   [][]float64
	ByzantineF  int
	SelectedIdx []int
	// LocallySafe is a pure ground-truth composition fact -- 2*honest >
	// total -- independent of what MultiKrumSelect actually selected.
	// This is deliberately the same rule
	// proofs/LeanFormalization/Theorem1BFT.lean's HTree.safe states: local
	// safety is about committee composition, not about any particular
	// selection algorithm's output. See TierResult.SafeLeafWeight for how
	// this gets (mis)credited upward -- the exact mechanism
	// hierarchical_composition_counterexample proves does not compose
	// soundly in general.
	LocallySafe bool
}

// TierResult is one tier's realized outcome for one round.
type TierResult struct {
	TierID          int
	Committees      []CommitteeResult
	TotalLeaves     int
	ByzantineLeaves int
	SafeLeafWeight  int
}

// RoundResult is one round's full realized outcome.
type RoundResult struct {
	Round int
	Seed  uint64 // base config seed; combined with Round, fully determines this round's RNG stream
	Tiers []TierResult
	// RootSafe is true iff every tier's SafeLeafWeight credits a majority
	// of that tier's TotalLeaves. A simple top-level combination across
	// tiers, not a recursive multi-level fold -- see committee.go's
	// TopologyConfig doc comment for why tiers are independent here
	// rather than a nested aggregation pipeline.
	RootSafe bool
}

// Simulator drives realistic, evolving inputs into the real production
// internal.MultiKrumSelect across many rounds. Node identity and each
// node's ground-truth IsByzantine label are fixed at construction and
// persist across rounds (internal.MultiKrumSelect never sees these
// labels); committee membership is resampled every round.
type Simulator struct {
	cfg       SimulatorConfig
	nodes     map[NodeID]*NodeState
	tierPools [][]NodeID // per-tier node pool, resampled into committees each round
	round     int

	// TraceSink, when non-nil, receives one JSONL TraceEvent line per
	// round_start/committee_formed/committee_selection/tier_aggregate/
	// round_summary -- see trace.go. Nil by default: strictly opt-in,
	// zero behavior change and zero overhead when untraced.
	TraceSink io.Writer
	traceSeq  atomic.Int64
}

// NewSimulator builds a Simulator and plants each tier's node population
// with cfg.ByzantineRate fraction marked Byzantine (ground truth, fixed
// for the run). Deterministic given cfg.Seed.
func NewSimulator(cfg SimulatorConfig) (*Simulator, error) {
	if cfg.Topology.Tiers <= 0 || cfg.Topology.CommitteesPerTier <= 0 || cfg.Topology.NodesPerCommittee <= 0 {
		return nil, fmt.Errorf("hbft: topology dimensions must be positive: %+v", cfg.Topology)
	}
	if cfg.ByzantineRate < 0 || cfg.ByzantineRate >= 1 {
		return nil, fmt.Errorf("hbft: byzantine rate must be in [0,1): %f", cfg.ByzantineRate)
	}
	if cfg.Adversary == nil {
		return nil, fmt.Errorf("hbft: adversary strategy required")
	}
	if cfg.Dimension <= 0 {
		return nil, fmt.Errorf("hbft: dimension must be positive")
	}
	// internal.MultiKrumSelect requires n > 2f+2; f is derived per
	// committee from hva.MaximumByzantineNodes(NodesPerCommittee), the
	// same 5/9-derived bound the rest of this repo uses (not a reinvented
	// number) -- verify the chosen topology actually satisfies
	// MultiKrumSelect's real precondition now, rather than discovering
	// that as an opaque runtime error mid-simulation.
	f := hva.MaximumByzantineNodes(cfg.Topology.NodesPerCommittee)
	if cfg.Topology.NodesPerCommittee <= 2*f+2 {
		return nil, fmt.Errorf(
			"hbft: NodesPerCommittee=%d yields f=%d via hva.MaximumByzantineNodes, "+
				"violating MultiKrumSelect's n > 2f+2 precondition (need NodesPerCommittee > %d)",
			cfg.Topology.NodesPerCommittee, f, 2*f+2)
	}

	rng := rand.New(rand.NewPCG(cfg.Seed, 0))
	nodes := make(map[NodeID]*NodeState, cfg.Topology.TotalNodes())
	tierPools := make([][]NodeID, cfg.Topology.Tiers)
	var nextID NodeID
	tierSize := cfg.Topology.CommitteesPerTier * cfg.Topology.NodesPerCommittee
	for t := 0; t < cfg.Topology.Tiers; t++ {
		pool := make([]NodeID, 0, tierSize)
		for i := 0; i < tierSize; i++ {
			id := nextID
			nextID++
			isByz := rng.Float64() < cfg.ByzantineRate
			nodes[id] = &NodeState{ID: id, TierID: t, IsByzantine: isByz}
			pool = append(pool, id)
		}
		tierPools[t] = pool
	}

	return &Simulator{cfg: cfg, nodes: nodes, tierPools: tierPools}, nil
}

// RunRound executes one round: resamples committee membership per tier,
// generates gradients (honest via a small-noise cluster, Byzantine via
// cfg.Adversary), calls the real internal.MultiKrumSelect per committee,
// and folds outcomes into per-tier weighted-safety bookkeeping mirroring
// HTree.safe's credited-weight rule.
func (s *Simulator) RunRound() (RoundResult, error) {
	rng := rand.New(rand.NewPCG(s.cfg.Seed, uint64(s.round)))

	result := RoundResult{Round: s.round, Seed: s.cfg.Seed}
	if s.TraceSink != nil {
		s.writeTrace(TraceEvent{
			Event: "round_start",
			Seq:   s.traceSeq.Add(1),
			Round: s.round,
			Seed:  s.cfg.Seed,
		})
	}
	allSafe := true

	for t := 0; t < s.cfg.Topology.Tiers; t++ {
		pool := append([]NodeID(nil), s.tierPools[t]...)
		rng.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })

		tierResult := TierResult{TierID: t}
		for c := 0; c < s.cfg.Topology.CommitteesPerTier; c++ {
			start := c * s.cfg.Topology.NodesPerCommittee
			members := pool[start : start+s.cfg.Topology.NodesPerCommittee]

			cr, err := s.runCommittee(rng, t, c, members)
			if err != nil {
				return RoundResult{}, err
			}
			tierResult.Committees = append(tierResult.Committees, cr)
			tierResult.TotalLeaves += len(cr.Labels)
			tierResult.ByzantineLeaves += countTrue(cr.Labels)
			if cr.LocallySafe {
				tierResult.SafeLeafWeight += len(cr.Labels)
			}
		}
		if 2*tierResult.SafeLeafWeight <= tierResult.TotalLeaves {
			allSafe = false
		}
		if s.TraceSink != nil {
			s.writeTrace(TraceEvent{
				Event:           "tier_aggregate",
				Seq:             s.traceSeq.Add(1),
				Round:           s.round,
				TierID:          t,
				TotalLeaves:     tierResult.TotalLeaves,
				ByzantineLeaves: tierResult.ByzantineLeaves,
				SafeLeafWeight:  tierResult.SafeLeafWeight,
			})
		}
		result.Tiers = append(result.Tiers, tierResult)
	}
	result.RootSafe = allSafe
	if s.TraceSink != nil {
		rootSafe := allSafe
		s.writeTrace(TraceEvent{
			Event:    "round_summary",
			Seq:      s.traceSeq.Add(1),
			Round:    s.round,
			RootSafe: &rootSafe,
		})
	}

	s.round++
	return result, nil
}

func (s *Simulator) runCommittee(rng *rand.Rand, tierID, committeeIdx int, members []NodeID) (CommitteeResult, error) {
	committeeID := fmt.Sprintf("t%d-c%d", tierID, committeeIdx)

	labels := make([]bool, len(members))
	var honestIdx, byzIdx []int
	for i, id := range members {
		labels[i] = s.nodes[id].IsByzantine
		if labels[i] {
			byzIdx = append(byzIdx, i)
		} else {
			honestIdx = append(honestIdx, i)
		}
	}

	if s.TraceSink != nil {
		memberIDs := make([]uint64, len(members))
		for i, id := range members {
			memberIDs[i] = uint64(id)
		}
		s.writeTrace(TraceEvent{
			Event:        "committee_formed",
			Seq:          s.traceSeq.Add(1),
			Round:        s.round,
			CommitteeID:  committeeID,
			TierID:       tierID,
			Members:      memberIDs,
			MemberLabels: append([]bool(nil), labels...),
		})
	}

	gradients := make([][]float64, len(members))
	honestGradients := make([][]float64, 0, len(honestIdx))
	for _, i := range honestIdx {
		g := make([]float64, s.cfg.Dimension)
		for d := range g {
			g[d] = 1.0 + (rng.Float64()-0.5)*0.02 // small-noise cluster
		}
		gradients[i] = g
		honestGradients = append(honestGradients, g)
	}
	if len(byzIdx) > 0 {
		byzGradients := s.cfg.Adversary.Craft(rng, s.cfg.Dimension, honestGradients, len(byzIdx))
		for k, i := range byzIdx {
			gradients[i] = byzGradients[k]
		}
	}

	f := hva.MaximumByzantineNodes(len(members))
	selected, _, err := internal.MultiKrumSelect(gradients, f, 0)
	if err != nil {
		return CommitteeResult{}, fmt.Errorf("hbft: MultiKrumSelect failed for tier %d committee %d: %w", tierID, committeeIdx, err)
	}

	byzCount := countTrue(labels)
	locallySafe := 2*(len(members)-byzCount) > len(members)

	if s.TraceSink != nil {
		safe := locallySafe
		s.writeTrace(TraceEvent{
			Event:       "committee_selection",
			Seq:         s.traceSeq.Add(1),
			Round:       s.round,
			CommitteeID: committeeID,
			TierID:      tierID,
			ByzantineF:  f,
			Gradients:   gradients,
			SelectedIdx: append([]int(nil), selected...),
			LocallySafe: &safe,
		})
	}

	return CommitteeResult{
		Committee: Committee{
			ID:      committeeID,
			TierID:  tierID,
			Members: append([]NodeID(nil), members...),
		},
		Labels:      labels,
		Gradients:   gradients,
		ByzantineF:  f,
		SelectedIdx: selected,
		LocallySafe: locallySafe,
	}, nil
}

func countTrue(bs []bool) int {
	n := 0
	for _, b := range bs {
		if b {
			n++
		}
	}
	return n
}

// Run executes rounds sequentially and returns all results.
func (s *Simulator) Run(rounds int) ([]RoundResult, error) {
	results := make([]RoundResult, 0, rounds)
	for i := 0; i < rounds; i++ {
		r, err := s.RunRound()
		if err != nil {
			return nil, err
		}
		results = append(results, r)
	}
	return results, nil
}
