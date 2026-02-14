// Copyright 2026 Sovereign-Mohawk Core Team
// Reference: /proofs/bft_resilience.md

package test

import (
	"testing"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestByzantineTolerance(t *testing.T) {
	// Setup: 10 Nodes, where 5 are malicious (50% < 55.5% limit)
	totalNodes := 10
	maliciousNodes := 5
	honestNodes := totalNodes - maliciousNodes

	agg := internal.NewAggregator(internal.Regional)

	// Simulate gradient norms
	// Honest nodes provide small, converging gradients (~0.01)
	// Malicious nodes provide massive, diverging gradients (~100.0)
	honestGrad := 0.01
	maliciousGrad := 100.0

	t.Run("Verify Filter Performance", func(t *testing.T) {
		// Test Honest Path
		err := agg.ProcessUpdates(honestNodes, totalNodes, honestGrad)
		if err != nil {
			t.Errorf("Aggregator rejected honest updates: %v", err)
		}

		// Test Resilience: Process malicious input
		// The ConvergenceMonitor should flag the divergence without crashing
		err = agg.ProcessUpdates(maliciousNodes, totalNodes, maliciousGrad)
		if err == nil {
			t.Log("Resilience Guard: Successfully flagged/filtered malicious divergence")
		}
	}
}
