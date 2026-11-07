// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0.
// Runtime witness for Gap 2 (measurability of stochastic gradient noise):
// under adversarial dropout patterns (missing/zeroed gradients), the
// aggregation path must produce finite, non-NaN gradients. This mirrors
// the measurability claim that masked gradients stay well-defined.

package federation

import (
	"context"
	"math"
	"testing"
)

func TestNoiseWitnessFiniteGradientsUnderDropout(t *testing.T) {
	config := TierConfig{
		TierID:                 "noise-witness-tier",
		MinQuorumSize:          2,
		ByzantineToleranceFrac: 0.33,
		AsyncMode:              true,
		StalenessWindow:        3,
		MaxBufferedGradients:   1000,
	}
	handler, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}

	// Mix of honest gradients and adversarial dropout (zeroed) gradients.
	for i := 0; i < 6; i++ {
		data := []float64{1.0, 2.0, 3.0}
		if i%3 == 0 {
			// Simulated dropout: zeroed gradient.
			data = []float64{0.0, 0.0, 0.0}
		}
		g := gradMsg(string(rune('a'+i)), data)
		g.AggregationRound = uint64(i%3 + 1)
		handler.bufferGradient(g)
	}

	handler.bufferMu.Lock()
	var collected []*GradientMessage
	for _, buf := range handler.childBuffers {
		collected = append(collected, buf...)
	}
	handler.bufferMu.Unlock()

	if len(collected) < config.MinQuorumSize {
		t.Skip("not enough gradients for aggregation")
	}

	res, method := handler.aggregate(collected)
	if res == nil {
		t.Fatalf("aggregate returned nil (method=%s)", method)
	}
	for i, v := range res.GradientData {
		if math.IsNaN(v) || math.IsInf(v, 0) {
			t.Fatalf("non-finite gradient at index %d: %v", i, v)
		}
	}
	if math.IsNaN(res.Norm) || math.IsInf(res.Norm, 0) {
		t.Fatalf("non-finite aggregate norm: %v", res.Norm)
	}

	// Also exercise the full flush path.
	handler2, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}
	for i := 0; i < 6; i++ {
		data := []float64{1.0, 2.0, 3.0}
		if i%3 == 0 {
			data = []float64{0.0, 0.0, 0.0}
		}
		g := gradMsg(string(rune('a'+i)), data)
		g.AggregationRound = uint64(i%3 + 1)
		handler2.bufferGradient(g)
	}
	handler2.flushPendingAggregations(context.Background())
	if handler2.gradientsAggregated == 0 {
		t.Fatal("expected async aggregation to produce a result")
	}
}
