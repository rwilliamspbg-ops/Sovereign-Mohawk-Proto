// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
//
// Tests for per-tier differential privacy epsilon accounting.

package federation

import (
	"context"
	"math"
	"testing"
	"time"
)

func TestNewDPTierTrackerStartsAtZero(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)

	if got := tracker.GetGlobalEpsilon(); got != 0 {
		t.Errorf("global epsilon = %v, want 0", got)
	}
	if got := tracker.GetTierEpsilon("regional-1"); got != 0 {
		t.Errorf("unseen tier epsilon = %v, want 0", got)
	}

	stats := tracker.GetGlobalStats()
	if stats["total_aggregations"].(int64) != 0 {
		t.Errorf("total_aggregations = %v, want 0", stats["total_aggregations"])
	}
	if stats["budget_exhausted"].(bool) {
		t.Error("budget should not be exhausted at construction")
	}
}

// The tracker's configured global budget must be the limit it actually
// enforces. NewDPTierTracker documents maxGlobalEpsilon as "global privacy
// budget (e.g., 2.0)"; enforcement must honor that value rather than an
// unrelated constant.
func TestRecordAggregationEnforcesConfiguredGlobalBudget(t *testing.T) {
	tracker := NewDPTierTracker(0.5, 1e-7)

	// Drive cumulative epsilon well past the configured 0.5 budget.
	var lastErr error
	exhausted := false
	for i := 0; i < 200 && !exhausted; i++ {
		lastErr = tracker.RecordAggregation("regional-1", 1, 1.0, 0.0001)
		if lastErr != nil {
			exhausted = true
		}
	}

	if !exhausted {
		t.Fatal("expected the configured global budget to be enforced, but 200 aggregations never tripped it")
	}
	if lastErr == nil {
		t.Fatal("expected a non-nil error once the budget is exhausted")
	}

	stats := tracker.GetGlobalStats()
	if !stats["budget_exhausted"].(bool) {
		t.Error("budget_exhausted should be set in stats")
	}

	// Once exhausted, further aggregations must be refused.
	if err := tracker.RecordAggregation("regional-1", 1, 1.0, 0.0001); err == nil {
		t.Error("expected subsequent aggregations to be refused after exhaustion")
	}
}

func TestRecordAggregationAccumulatesEpsilon(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)

	if err := tracker.RecordAggregation("regional-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("RecordAggregation: %v", err)
	}

	first := tracker.GetTierEpsilon("regional-1")
	if first <= 0 {
		t.Fatalf("tier epsilon = %v, want > 0", first)
	}

	if err := tracker.RecordAggregation("regional-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("second RecordAggregation: %v", err)
	}

	second := tracker.GetTierEpsilon("regional-1")
	if second <= first {
		t.Errorf("epsilon did not accumulate: first = %v, second = %v", first, second)
	}

	stats := tracker.GetGlobalStats()
	if stats["total_aggregations"].(int64) != 2 {
		t.Errorf("total_aggregations = %v, want 2", stats["total_aggregations"])
	}
}

func TestRecordAggregationPerTierIsolation(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)

	if err := tracker.RecordAggregation("regional-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("regional-1: %v", err)
	}

	if got := tracker.GetTierEpsilon("regional-2"); got != 0 {
		t.Errorf("regional-2 epsilon = %v, want 0 (tiers are independent)", got)
	}

	if err := tracker.RecordAggregation("continental-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("continental-1: %v", err)
	}

	stats := tracker.GetGlobalStats()
	if stats["num_tiers"].(int) != 2 {
		t.Errorf("num_tiers = %v, want 2", stats["num_tiers"])
	}

	// Both tiers contributed to the global figure.
	tierEps := stats["tier_epsilon"].(map[string]float64)
	if len(tierEps) != 2 {
		t.Errorf("tier_epsilon has %d entries, want 2", len(tierEps))
	}
	for _, tier := range []string{"regional-1", "continental-1"} {
		if tierEps[tier] <= 0 {
			t.Errorf("tier %q epsilon = %v, want > 0", tier, tierEps[tier])
		}
	}
}

func TestRecordAggregationRejectsInvalidParameters(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)

	for _, tc := range []struct {
		name   string
		count  int
		sample float64
		noise  float64
	}{
		{"zero count", 0, 1.0, 0.01},
		{"negative count", -1, 1.0, 0.01},
		{"zero sampling rate", 10, 0.0, 0.01},
		{"negative sampling rate", 10, -0.5, 0.01},
		{"zero noise", 10, 1.0, 0.0},
		{"negative noise", 10, 1.0, -0.01},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := tracker.RecordAggregation("regional-1", tc.count, tc.sample, tc.noise); err == nil {
				t.Error("expected an error for invalid DP parameters")
			}
		})
	}

	// Rejected calls must not have advanced the counters.
	if got := tracker.GetGlobalStats()["total_aggregations"].(int64); got != 0 {
		t.Errorf("total_aggregations = %d, want 0 — invalid calls must not count", got)
	}
}

func TestGetTierStatsReflectsRecordings(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)

	stats := tracker.GetTierStats("regional-1")
	if stats["aggregations"].(int64) != 0 {
		t.Errorf("aggregations = %v, want 0", stats["aggregations"])
	}

	if err := tracker.RecordAggregation("regional-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("RecordAggregation: %v", err)
	}

	stats = tracker.GetTierStats("regional-1")
	if stats["aggregations"].(int64) != 1 {
		t.Errorf("aggregations = %v, want 1", stats["aggregations"])
	}
	if stats["epsilon"].(float64) <= 0 {
		t.Errorf("epsilon = %v, want > 0", stats["epsilon"])
	}
}

// More noise must mean less privacy loss; more participants must too.
func TestEpsilonDecreasesWithNoiseAndSampleSize(t *testing.T) {
	lowNoise := calculateGaussianEpsilon(1.0, 0.001, 100, 1e-7)
	highNoise := calculateGaussianEpsilon(1.0, 0.01, 100, 1e-7)
	if highNoise >= lowNoise {
		t.Errorf("more noise should not increase epsilon: low = %v, high = %v", lowNoise, highNoise)
	}

	fewNodes := calculateGaussianEpsilon(1.0, 0.001, 10, 1e-7)
	manyNodes := calculateGaussianEpsilon(1.0, 0.001, 1000, 1e-7)
	if manyNodes >= fewNodes {
		t.Errorf("larger cohort should not increase epsilon: few = %v, many = %v", fewNodes, manyNodes)
	}
}

func TestCalculateGaussianEpsilonMatchesDocumentedFormula(t *testing.T) {
	const sample, noise, count, delta = 0.5, 0.01, 200.0, 1e-7

	got := calculateGaussianEpsilon(sample, noise, count, delta)

	// epsilon = sqrt(2) * sqrt(log(2/delta)) / (noise * sqrt(n * sample))
	want := (math.Sqrt(2.0) * math.Sqrt(math.Log(2.0/delta))) / (noise * math.Sqrt(count*sample))
	if math.Abs(got-want) > 1e-9 {
		t.Errorf("epsilon = %v, want %v", got, want)
	}
}

func TestCalculateGaussianEpsilonZeroForInvalidInput(t *testing.T) {
	for _, tc := range []struct {
		name                 string
		sample, noise, count float64
	}{
		{"zero noise", 1.0, 0, 100},
		{"negative noise", 1.0, -0.01, 100},
		{"zero sample", 0, 0.01, 100},
		{"negative sample", -1, 0.01, 100},
		{"zero count", 1.0, 0.01, 0},
		{"negative count", 1.0, 0.01, -5},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := calculateGaussianEpsilon(tc.sample, tc.noise, tc.count, 1e-7); got != 0 {
				t.Errorf("epsilon = %v, want 0", got)
			}
		})
	}
}

func TestSetDPParametersValidatesInput(t *testing.T) {
	c := &CoordinatorWithDP{samplingRate: 1.0, noiseMagnitude: 0.001}

	c.SetDPParameters(0.5, 0.01)
	if c.samplingRate != 0.5 {
		t.Errorf("samplingRate = %v, want 0.5", c.samplingRate)
	}
	if c.noiseMagnitude != 0.01 {
		t.Errorf("noiseMagnitude = %v, want 0.01", c.noiseMagnitude)
	}

	// Out-of-range and non-positive values must be ignored, not applied.
	c.SetDPParameters(1.5, -1.0)
	if c.samplingRate != 0.5 {
		t.Errorf("samplingRate = %v, want 0.5 (out-of-range rejected)", c.samplingRate)
	}
	if c.noiseMagnitude != 0.01 {
		t.Errorf("noiseMagnitude = %v, want 0.01 (negative rejected)", c.noiseMagnitude)
	}

	c.SetDPParameters(0, 0)
	if c.samplingRate != 0.5 {
		t.Errorf("samplingRate = %v, want 0.5 (zero rejected)", c.samplingRate)
	}
}

// A CoordinatorWithDP with no tracker must be a safe no-op rather than a panic.
func TestRecordAggregationWithoutTracker(t *testing.T) {
	c := &CoordinatorWithDP{samplingRate: 1.0, noiseMagnitude: 0.01}

	if err := c.RecordAggregation(10); err != nil {
		t.Errorf("RecordAggregation with nil tracker = %v, want nil", err)
	}
}

func TestCoordinatorWithDPRecordsThroughTracker(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)
	c := &CoordinatorWithDP{
		dpTracker:      tracker,
		tierNodeID:     "regional-7",
		samplingRate:   1.0,
		noiseMagnitude: 0.01,
	}

	if err := c.RecordAggregation(25); err != nil {
		t.Fatalf("RecordAggregation: %v", err)
	}

	if got := tracker.GetTierEpsilon("regional-7"); got <= 0 {
		t.Errorf("tier epsilon = %v, want > 0 — aggregation did not reach the tracker", got)
	}
	if got := tracker.GetGlobalStats()["total_aggregations"].(int64); got != 1 {
		t.Errorf("total_aggregations = %d, want 1", got)
	}
}

// MonitorDPBudget must return promptly when its context is cancelled, and must
// not panic on a tracker that has recorded nothing.
func TestMonitorDPBudgetHonorsContextCancellation(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)
	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		MonitorDPBudget(ctx, tracker, 5*time.Millisecond)
		close(done)
	}()

	time.Sleep(20 * time.Millisecond)
	cancel()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("MonitorDPBudget did not return after context cancellation")
	}
}

func TestMonitorDPBudgetRunsTicksWithoutPanic(t *testing.T) {
	// The Gaussian epsilon formula yields large values for small noise and
	// small cohorts, so give this a budget the single aggregation fits inside.
	tracker := NewDPTierTracker(1000.0, 1e-7)
	if err := tracker.RecordAggregation("regional-1", 10, 1.0, 0.01); err != nil {
		t.Fatalf("RecordAggregation: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Millisecond)
	defer cancel()

	done := make(chan struct{})
	go func() {
		MonitorDPBudget(ctx, tracker, 5*time.Millisecond)
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("MonitorDPBudget did not exit at context deadline")
	}
}
