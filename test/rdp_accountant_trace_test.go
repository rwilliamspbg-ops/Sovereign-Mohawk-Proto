package test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"math/big"
	"os"
	"path/filepath"
	"testing"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// TestRDPAccountantTrace drives a realistic multi-shard, multi-round
// RDPAccountant execution with tracing enabled and writes the resulting
// JSONL trace to test-results/rdp-trace/trace.jsonl. That file is the input
// to the Lean trace validator (proofs/TraceValidator/RDPAccountant.lean),
// which replays every event through the already-proven composeRDP ledger
// model (proofs/Refinement/RDPAccountant.lean) and checks the Go execution
// matches it exactly -- extending the four fixed vectors in
// FORMAL_TRACEABILITY_MATRIX.md row 13 to a live, dynamic call sequence.
//
// The scenario: three shards each take two RecordShardStepRat steps, with
// a CheckBudget call after each shard's second step (all within budget),
// then a final large RecordStepRat step that deliberately exceeds the
// budget, followed by one last CheckBudget call that must report exceeded
// -- so the trace exercises both budget outcomes, not just the passing case.
func TestRDPAccountantTrace(t *testing.T) {
	var buf bytes.Buffer
	// MaxBudget=5.0 leaves headroom above CheckBudget's fixed conversion
	// term (log(1/delta)/(alpha-1) ~= 1.279 at delta=1e-5, alpha=10 -- the
	// accountant's default Alpha) plus this scenario's ~0.30 shard total,
	// so the three mid-scenario checks land comfortably within budget
	// (current ~= 1.58 < 5.0) while the final +10 push deliberately clears
	// it (current ~= 11.58 > 5.0).
	acc := internal.NewRDPAccountant(5.0, 1e-5)
	acc.TraceSink = &buf

	shardSteps := map[string][2]*big.Rat{
		"shard-a": {big.NewRat(1, 20), big.NewRat(3, 50)},
		"shard-b": {big.NewRat(1, 10), big.NewRat(1, 25)},
		"shard-c": {big.NewRat(3, 100), big.NewRat(1, 50)},
	}
	// Deterministic order for a reproducible trace.
	shardOrder := []string{"shard-a", "shard-b", "shard-c"}

	for _, shard := range shardOrder {
		steps := shardSteps[shard]
		acc.RecordShardStepRat(shard, steps[0])
		acc.RecordShardStepRat(shard, steps[1])
		if err := acc.CheckBudget(); err != nil {
			t.Fatalf("shard %s: expected budget within limit mid-scenario, got: %v", shard, err)
		}
	}

	// Push the ledger over MaxBudget (5.0) on purpose.
	acc.RecordStepRat(big.NewRat(10, 1))
	if err := acc.CheckBudget(); err == nil {
		t.Fatal("expected final CheckBudget to report budget exceeded, got nil error")
	}

	events := parseTraceLines(t, buf.Bytes())
	if len(events) == 0 {
		t.Fatal("expected at least one traced event, got none")
	}
	last := events[len(events)-1]
	if last.Event != "check_budget" || last.BudgetOK == nil || *last.BudgetOK {
		t.Fatalf("expected final traced event to be a failing check_budget, got %+v", last)
	}

	writeTraceArtifact(t, buf.Bytes())
}

func parseTraceLines(t *testing.T, data []byte) []internal.TraceEvent {
	t.Helper()
	var events []internal.TraceEvent
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var ev internal.TraceEvent
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

// writeTraceArtifact writes the raw trace to
// <repo-root>/test-results/rdp-trace/trace.jsonl. Go test binaries run with
// their working directory set to the package's source directory (test/),
// so ".." resolves to the repo root regardless of where `go test` itself
// was invoked from -- matching how this repo's other CI-consumed test
// artifacts are laid out under test-results/.
func writeTraceArtifact(t *testing.T, data []byte) {
	t.Helper()
	outDir := filepath.Join("..", "test-results", "rdp-trace")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		t.Fatalf("failed to create trace output dir %s: %v", outDir, err)
	}
	outPath := filepath.Join(outDir, "trace.jsonl")
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		t.Fatalf("failed to write trace artifact %s: %v", outPath, err)
	}
}
