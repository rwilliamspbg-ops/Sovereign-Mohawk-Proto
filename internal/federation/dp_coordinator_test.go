package federation

import (
	"context"
	"testing"
)

func dpTestTierConfig(tierID string) TierConfig {
	return TierConfig{
		TierID:        tierID,
		Level:         TierRegional,
		ChildNodeIDs:  []string{},
		MinQuorumSize: 1,
	}
}

func TestNewCoordinatorWithDPPropagatesConfig(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)
	cfg := dpTestTierConfig("regional-42")

	c, err := NewCoordinatorWithDP(cfg, "127.0.0.1:0", "", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}
	if c == nil {
		t.Fatal("NewCoordinatorWithDP returned nil")
	}
	if c.coordinator == nil {
		t.Fatal("wrapped coordinator is nil")
	}
	if c.dpTracker != tracker {
		t.Error("dpTracker was not preserved")
	}
	if c.tierNodeID != cfg.TierID {
		t.Errorf("tierNodeID = %q, want %q", c.tierNodeID, cfg.TierID)
	}
	if c.samplingRate != 1.0 {
		t.Errorf("default samplingRate = %v, want 1.0", c.samplingRate)
	}
	if c.noiseMagnitude != 0.001 {
		t.Errorf("default noiseMagnitude = %v, want 0.001", c.noiseMagnitude)
	}
	if c.coordinator.rpcServer == nil {
		t.Error("coordinator rpcServer is nil")
	}
	if c.coordinator.rpcClient != nil {
		t.Error("rpcClient should be nil when no parent address is given")
	}
	if err := c.Stop(); err != nil {
		t.Errorf("Stop without a parent client: %v", err)
	}
	if err := c.coordinator.Close(); err != nil {
		t.Errorf("Close: %v", err)
	}
}

func TestNewCoordinatorWithDPWithParentCreatesClient(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)
	c, err := NewCoordinatorWithDP(dpTestTierConfig("regional-1"), "127.0.0.1:0", "127.0.0.1:59999", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}
	if c.coordinator.rpcClient == nil {
		t.Fatal("expected an rpcClient when a parent address is given")
	}
	if err := c.Stop(); err != nil {
		t.Errorf("Stop: %v", err)
	}
	if err := c.coordinator.Close(); err != nil {
		t.Errorf("Close: %v", err)
	}
}

func TestCoordinatorWithDPStartAndStop(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)
	c, err := NewCoordinatorWithDP(dpTestTierConfig("regional-1"), "127.0.0.1:0", "", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}

	if err := c.Start(context.Background(), "127.0.0.1:0"); err != nil {
		t.Fatalf("Start: %v", err)
	}
	if err := c.Stop(); err != nil {
		t.Errorf("Stop: %v", err)
	}
	if err := c.coordinator.rpcServer.Close(); err != nil {
		t.Errorf("rpcServer Close: %v", err)
	}
}

func TestGetDPStatsFreshCoordinator(t *testing.T) {
	tracker := NewDPTierTracker(2.0, 1e-7)
	c, err := NewCoordinatorWithDP(dpTestTierConfig("regional-1"), "127.0.0.1:0", "", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}
	defer func() { _ = c.coordinator.Close() }()

	stats := c.GetDPStats()
	if got := stats["total_aggregations"].(int64); got != 0 {
		t.Errorf("total_aggregations = %d, want 0", got)
	}
	if got := stats["global_epsilon"].(float64); got != 0 {
		t.Errorf("global_epsilon = %v, want 0", got)
	}
	if got := stats["num_tiers"].(int); got != 0 {
		t.Errorf("num_tiers = %d, want 0", got)
	}
	if stats["budget_exhausted"].(bool) {
		t.Error("budget_exhausted = true, want false on a fresh tracker")
	}
	if tierEps := stats["tier_epsilon"].(map[string]float64); len(tierEps) != 0 {
		t.Errorf("tier_epsilon = %v, want an empty map", tierEps)
	}
}

func TestGetDPStatsAfterRecordings(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)
	c, err := NewCoordinatorWithDP(dpTestTierConfig("regional-9"), "127.0.0.1:0", "", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}
	defer func() { _ = c.coordinator.Close() }()

	c.SetDPParameters(0.5, 0.02)
	for i := 0; i < 2; i++ {
		if err := c.RecordAggregation(25); err != nil {
			t.Fatalf("RecordAggregation %d: %v", i, err)
		}
	}

	stats := c.GetDPStats()
	if got := stats["total_aggregations"].(int64); got != 2 {
		t.Errorf("total_aggregations = %d, want 2", got)
	}
	if got := stats["num_tiers"].(int); got != 1 {
		t.Errorf("num_tiers = %d, want 1", got)
	}
	if got := stats["global_epsilon"].(float64); got <= 0 {
		t.Errorf("global_epsilon = %v, want > 0", got)
	}
	tierEps := stats["tier_epsilon"].(map[string]float64)
	if got := tierEps["regional-9"]; got <= 0 {
		t.Errorf("tier epsilon = %v, want > 0", got)
	}
	if stats["budget_exhausted"].(bool) {
		t.Error("budget_exhausted = true, want false")
	}
}

func TestGetDPStatsAfterRejectedAggregation(t *testing.T) {
	tracker := NewDPTierTracker(1000.0, 1e-7)
	c, err := NewCoordinatorWithDP(dpTestTierConfig("regional-1"), "127.0.0.1:0", "", tracker)
	if err != nil {
		t.Fatalf("NewCoordinatorWithDP: %v", err)
	}
	defer func() { _ = c.coordinator.Close() }()

	if err := c.RecordAggregation(0); err == nil {
		t.Fatal("RecordAggregation(0) should be rejected")
	}
	if err := c.RecordAggregation(-5); err == nil {
		t.Fatal("RecordAggregation(-5) should be rejected")
	}

	stats := c.GetDPStats()
	if got := stats["total_aggregations"].(int64); got != 0 {
		t.Errorf("total_aggregations = %d, want 0", got)
	}
	if got := stats["global_epsilon"].(float64); got != 0 {
		t.Errorf("global_epsilon = %v, want 0", got)
	}
	// RecordAggregation creates the per-tier accountant before it validates
	// its parameters, so a rejected call still leaves an empty tier entry.
	if got := stats["num_tiers"].(int); got != 1 {
		t.Errorf("num_tiers = %d, want 1 (accountant is created before validation)", got)
	}
	tierEps := stats["tier_epsilon"].(map[string]float64)
	if len(tierEps) != 1 {
		t.Fatalf("tier_epsilon = %v, want one entry", tierEps)
	}
	if got := tierEps["regional-1"]; got != 0 {
		t.Errorf("rejected tier epsilon = %v, want 0", got)
	}
}

// GetDPStats has no nil-tracker guard, unlike RecordAggregation (which is a
// documented no-op). This pins the current zero-value behaviour so a later
// guard cannot land silently; update this test if one is added.
func TestGetDPStatsNilTrackerPanics(t *testing.T) {
	c := &CoordinatorWithDP{}
	defer func() {
		if recover() == nil {
			t.Error("GetDPStats with a nil dpTracker should panic (no nil guard)")
		}
	}()
	c.GetDPStats()
}
