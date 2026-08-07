package test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hbft"
)

// TestHBFTStatisticalSanityCheck runs the Technique-B empirical trial batch
// (see internal/hbft/statcheck.go and
// proofs/TraceValidator/HierarchicalBFTBoundEval.lean for the full scope
// statement -- this is an empirical regression tripwire, NOT machine-
// checked verification) and writes the result to
// test-results/hbft-statcheck/result.json for the CI workflow to feed into
// the Lean bound evaluator, which performs the actual pass/fail comparison
// against the already-proven chernoff_hierarchical_bound.
//
// Parameters (T=12, c=27, k=14, p=0.3) must exactly match
// HierarchicalBFTBoundEval.lean's toyCommittees/toyCommitteeSize/
// toyFailureThreshold/toyByzantineRate -- chosen so the true failure
// probability (~0.158, computed independently during design of this test)
// is small but not so astronomically small that 5000 trials would
// trivially observe zero failures either way, which would make the
// sanity check numerically meaningless.
func TestHBFTStatisticalSanityCheck(t *testing.T) {
	result := hbft.RunStatCheck(hbft.StatCheckConfig{
		Trials:            5000,
		Committees:        12,
		NodesPerCommittee: 27,
		FailureThreshold:  14,
		ByzantineRate:     0.3,
		Seed:              20260807,
	})

	t.Logf("empirical failure rate: %d/%d = %f", result.Failures, result.Trials, result.EmpiricalRate)

	outDir := filepath.Join("..", "test-results", "hbft-statcheck")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		t.Fatalf("failed to create output dir %s: %v", outDir, err)
	}
	outPath := filepath.Join(outDir, "result.json")
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		t.Fatalf("failed to marshal result: %v", err)
	}
	if err := os.WriteFile(outPath, data, 0o644); err != nil {
		t.Fatalf("failed to write %s: %v", outPath, err)
	}
}
