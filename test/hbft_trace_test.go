package test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hbft"
)

// TestHBFTTrace drives a realistic multi-tier, multi-round hierarchical
// Multi-Krum execution with tracing enabled and writes the resulting
// JSONL trace to test-results/hbft-trace/trace.jsonl. That file is the
// input to the Lean trace validator
// (proofs/TraceValidator/HierarchicalBFT.lean, added in a later PR),
// which replays every committee_selection event by independently
// re-running Multi-Krum selection on the recorded Gradients and
// cross-checking against SelectedIdx, and folds committee outcomes into
// per-tier weighted-safety bookkeeping mirroring
// proofs/LeanFormalization/Theorem1BFT.lean's HTree.safe credited-weight
// rule -- extending row 12's four fixed vectors to every committee-round
// in a live, dynamic trace.
//
// Scale: 3 tiers, 4 committees per tier, 27 nodes per committee (the
// smallest size comfortably satisfying MultiKrumSelect's n > 2f+2
// precondition at the hva-derived f=12), 6 rounds -- deliberately small
// for CI feasibility (MultiKrumSelect is O(n^2) per committee); see the
// implementation plan's "Scale" section for why the actual 10M-node/
// 50,000-per-committee deployment scale isn't CI-feasible.
//
// The scenario uses a CollusionAdversary (Byzantine members biased toward
// the honest centroid, not a trivial far-outlier) so the trace exercises
// the actually interesting case Multi-Krum's guarantee is about, not a
// strawman.
func TestHBFTTrace(t *testing.T) {
	var buf bytes.Buffer
	sim, err := hbft.NewSimulator(hbft.SimulatorConfig{
		Topology:      hbft.TopologyConfig{Tiers: 3, CommitteesPerTier: 4, NodesPerCommittee: 27},
		ByzantineRate: 0.2,
		Adversary:     hbft.CollusionAdversary{Bias: 3.0},
		Dimension:     4,
		Seed:          20260807,
	})
	if err != nil {
		t.Fatalf("NewSimulator failed: %v", err)
	}
	sim.TraceSink = &buf

	results, err := sim.Run(6)
	if err != nil {
		t.Fatalf("Run failed: %v", err)
	}
	if len(results) != 6 {
		t.Fatalf("expected 6 round results, got %d", len(results))
	}

	events := parseHBFTTraceLines(t, buf.Bytes())
	if len(events) == 0 {
		t.Fatal("expected at least one traced event, got none")
	}

	roundStarts, committeeFormed, committeeSelections, tierAggregates, roundSummaries := 0, 0, 0, 0, 0
	for _, ev := range events {
		switch ev.Event {
		case "round_start":
			roundStarts++
		case "committee_formed":
			committeeFormed++
		case "committee_selection":
			committeeSelections++
		case "tier_aggregate":
			tierAggregates++
		case "round_summary":
			roundSummaries++
		default:
			t.Fatalf("unexpected event type: %s", ev.Event)
		}
	}
	if roundStarts != 6 || roundSummaries != 6 {
		t.Fatalf("expected 6 round_start and 6 round_summary events, got %d and %d", roundStarts, roundSummaries)
	}
	wantPerRound := 3 * 4 // tiers * committeesPerTier
	if committeeFormed != 6*wantPerRound || committeeSelections != 6*wantPerRound {
		t.Fatalf("expected %d committee_formed and committee_selection events, got %d and %d",
			6*wantPerRound, committeeFormed, committeeSelections)
	}
	if tierAggregates != 6*3 {
		t.Fatalf("expected %d tier_aggregate events (6 rounds * 3 tiers), got %d", 6*3, tierAggregates)
	}

	writeHBFTTraceArtifact(t, buf.Bytes())
}

func parseHBFTTraceLines(t *testing.T, data []byte) []hbft.TraceEvent {
	t.Helper()
	var events []hbft.TraceEvent
	scanner := bufio.NewScanner(bytes.NewReader(data))
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var ev hbft.TraceEvent
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

// writeHBFTTraceArtifact writes the raw trace to
// <repo-root>/test-results/hbft-trace/trace.jsonl, following the same
// convention test/rdp_accountant_trace_test.go's writeTraceArtifact
// established (Go test binaries run with cwd set to the package's source
// directory, so ".." resolves to the repo root).
func writeHBFTTraceArtifact(t *testing.T, data []byte) {
	t.Helper()
	outDir := filepath.Join("..", "test-results", "hbft-trace")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		t.Fatalf("failed to create trace output dir %s: %v", outDir, err)
	}
	outPath := filepath.Join(outDir, "trace.jsonl")
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		t.Fatalf("failed to write trace artifact %s: %v", outPath, err)
	}
}
