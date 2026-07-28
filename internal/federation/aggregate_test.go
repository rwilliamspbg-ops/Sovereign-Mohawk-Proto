// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Tests for aggregate()/multiKrumAggregate(): confirms flushPendingAggregations
// is actually wired to Byzantine-robust Multi-Krum selection rather than a
// plain mean, and that it falls back sanely when there aren't enough updates.

package federation

import (
	"math"
	"testing"
)

func gradMsg(id string, data []float64) *GradientMessage {
	g := &GradientMessage{
		GradientID:     id,
		SourceNodeID:   id,
		DimensionCount: len(data),
		GradientData:   data,
	}
	for _, v := range data {
		g.Norm += v * v
	}
	return g
}

// TestAggregateRejectsPoisonedUpdates builds a set of honest gradients
// clustered near a known vector, plus a minority of poisoned outliers far
// away, and checks that the aggregate lands near the honest cluster instead
// of being dragged toward the poisoned updates by a plain mean.
func TestAggregateRejectsPoisonedUpdates(t *testing.T) {
	config := TierConfig{
		TierID:                 "test-tier",
		MinQuorumSize:          1,
		ByzantineToleranceFrac: 0.33,
	}
	handler, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}

	dim := 8
	honestValue := 1.0
	poisonValue := 1000.0 // far enough away that a plain mean would be dominated

	var gradients []*GradientMessage
	honestCount := 7
	poisonCount := 3 // 10 total, f = floor(0.33*10) = 3, requires n > 2f+2 = 8; 10 > 8 OK

	for i := 0; i < honestCount; i++ {
		data := make([]float64, dim)
		for j := range data {
			// Small jitter so updates aren't degenerate-identical.
			data[j] = honestValue + 0.01*float64(i)
		}
		gradients = append(gradients, gradMsg("honest", data))
	}
	for i := 0; i < poisonCount; i++ {
		data := make([]float64, dim)
		for j := range data {
			data[j] = poisonValue
		}
		gradients = append(gradients, gradMsg("poison", data))
	}

	result, method := handler.aggregate(gradients)
	if method != "multi-krum" {
		t.Fatalf("expected multi-krum aggregation with n=%d, got fallback method %q", len(gradients), method)
	}
	if len(result.GradientData) != dim {
		t.Fatalf("expected result dimension %d, got %d", dim, len(result.GradientData))
	}

	for i, v := range result.GradientData {
		if math.Abs(v-honestValue) > 1.0 {
			t.Fatalf("aggregate dimension %d = %.4f, expected close to honest cluster value %.1f (poisoned updates leaked into aggregate)",
				i, v, honestValue)
		}
	}

	// Sanity: a plain mean of the same input WOULD be dominated by the
	// poisoned updates, proving this test is actually discriminating.
	plainMean := handler.simpleAggregate(gradients)
	if math.Abs(plainMean.GradientData[0]-honestValue) < 1.0 {
		t.Fatalf("test setup invalid: plain mean (%.4f) should have been dominated by poisoned updates", plainMean.GradientData[0])
	}
}

// TestAggregateFallsBackWithTooFewUpdates ensures small tiers (below
// Multi-Krum's n > 2f+2 requirement) still produce a usable aggregate via
// the mean fallback instead of erroring out.
func TestAggregateFallsBackWithTooFewUpdates(t *testing.T) {
	config := TierConfig{
		TierID:                 "small-tier",
		MinQuorumSize:          1,
		ByzantineToleranceFrac: 0.33,
	}
	handler, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}

	gradients := []*GradientMessage{
		gradMsg("a", []float64{1, 2, 3}),
		gradMsg("b", []float64{3, 2, 1}),
	}

	result, method := handler.aggregate(gradients)
	if method != "mean-fallback" {
		t.Fatalf("expected mean-fallback with n=2, got %q", method)
	}
	want := []float64{2, 2, 2}
	for i, v := range result.GradientData {
		if math.Abs(v-want[i]) > 1e-9 {
			t.Fatalf("dimension %d = %.4f, want %.4f", i, v, want[i])
		}
	}
}

// TestAggregateSingleUpdate covers the degenerate n=1 case.
func TestAggregateSingleUpdate(t *testing.T) {
	config := TierConfig{TierID: "solo-tier", ByzantineToleranceFrac: 0.33}
	handler, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}

	gradients := []*GradientMessage{gradMsg("only", []float64{5, 5, 5})}
	result, method := handler.aggregate(gradients)
	if method != "mean-fallback" {
		t.Fatalf("expected mean-fallback with n=1, got %q", method)
	}
	for _, v := range result.GradientData {
		if v != 5 {
			t.Fatalf("expected 5, got %v", v)
		}
	}
}
