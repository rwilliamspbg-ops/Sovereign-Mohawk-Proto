// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
//
// Tests for cluster topology: membership, redundant path assignment,
// Byzantine reputation scoring, and health-check exclusion.

package cluster

import (
	"sync"
	"testing"
	"time"
)

func TestNewTopologyStartsEmpty(t *testing.T) {
	topo := NewTopology()

	if got := topo.GetNodeCount(EdgeNode); got != 0 {
		t.Errorf("EdgeNode count = %d, want 0", got)
	}
	if got := topo.GetNodeCount(RegionalAggregator); got != 0 {
		t.Errorf("RegionalAggregator count = %d, want 0", got)
	}
	if got := topo.GetHealthyNodes(); got != 0 {
		t.Errorf("healthy count = %d, want 0", got)
	}
	if topo.lastUpdate.IsZero() {
		t.Error("lastUpdate should be initialized by NewTopology")
	}
}

func TestRegisterNodeCountsByRole(t *testing.T) {
	topo := NewTopology()

	topo.RegisterNode("edge-1", EdgeNode)
	topo.RegisterNode("edge-2", EdgeNode)
	topo.RegisterNode("agg-1", RegionalAggregator)
	topo.RegisterNode("coord-1", GlobalCoordinator)

	if got := topo.GetNodeCount(EdgeNode); got != 2 {
		t.Errorf("EdgeNode count = %d, want 2", got)
	}
	if got := topo.GetNodeCount(RegionalAggregator); got != 1 {
		t.Errorf("RegionalAggregator count = %d, want 1", got)
	}
	if got := topo.GetNodeCount(GlobalCoordinator); got != 1 {
		t.Errorf("GlobalCoordinator count = %d, want 1", got)
	}
}

func TestRegisterNodeInitializesDefaults(t *testing.T) {
	topo := NewTopology()
	if err := topo.RegisterNode("edge-1", EdgeNode); err != nil {
		t.Fatalf("RegisterNode: %v", err)
	}

	topo.mu.RLock()
	node := topo.nodes["edge-1"]
	topo.mu.RUnlock()

	if node == nil {
		t.Fatal("node not stored")
	}
	if node.Reputation != 1.0 {
		t.Errorf("Reputation = %v, want 1.0", node.Reputation)
	}
	if !node.IsHealthy {
		t.Error("newly registered node should start healthy")
	}
	if node.ID != "edge-1" {
		t.Errorf("ID = %q, want %q", node.ID, "edge-1")
	}
	if time.Since(node.LastHeartbeat) > time.Minute {
		t.Error("LastHeartbeat should be set to now at registration")
	}
}

func TestAssignAggregatorTakesThreeWayRedundancy(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("edge-1", EdgeNode)

	aggs := []string{"agg-1", "agg-2", "agg-3", "agg-4", "agg-5"}
	if err := topo.AssignAggregator("edge-1", aggs); err != nil {
		t.Fatalf("AssignAggregator: %v", err)
	}

	got, err := topo.GetAssignedAggregators("edge-1")
	if err != nil {
		t.Fatalf("GetAssignedAggregators: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("assigned %d aggregators, want 3", len(got))
	}
	for i := 0; i < 3; i++ {
		if got[i] != aggs[i] {
			t.Errorf("aggregator[%d] = %q, want %q", i, got[i], aggs[i])
		}
	}
}

// AssignAggregator must copy the caller's slice. Storing a subslice of the
// caller's backing array would let a later mutation of that array silently
// change cluster routing.
func TestAssignAggregatorCopiesCallerSlice(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("edge-1", EdgeNode)

	aggs := []string{"agg-1", "agg-2", "agg-3"}
	if err := topo.AssignAggregator("edge-1", aggs); err != nil {
		t.Fatalf("AssignAggregator: %v", err)
	}

	aggs[0] = "MUTATED"

	got, err := topo.GetAssignedAggregators("edge-1")
	if err != nil {
		t.Fatalf("GetAssignedAggregators: %v", err)
	}
	if got[0] != "agg-1" {
		t.Errorf("aggregator[0] = %q, want %q — topology aliases the caller's slice", got[0], "agg-1")
	}
}

func TestAssignAggregatorFewerThanThree(t *testing.T) {
	topo := NewTopology()

	for _, tc := range []struct {
		name string
		aggs []string
		want int
	}{
		{"two available", []string{"agg-1", "agg-2"}, 2},
		{"one available", []string{"agg-1"}, 1},
		{"none available", nil, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := topo.AssignAggregator("edge-1", tc.aggs); err != nil {
				t.Fatalf("AssignAggregator: %v", err)
			}
			got, err := topo.GetAssignedAggregators("edge-1")
			if err != nil {
				t.Fatalf("GetAssignedAggregators: %v", err)
			}
			if len(got) != tc.want {
				t.Errorf("assigned %d aggregators, want %d", len(got), tc.want)
			}
		})
	}
}

func TestGetAssignedAggregatorsUnknownNode(t *testing.T) {
	topo := NewTopology()

	if _, err := topo.GetAssignedAggregators("never-registered"); err == nil {
		t.Error("expected an error for an unassigned node")
	}
}

// GetAssignedAggregators must not hand out the topology's internal slice, which
// callers could mutate without holding the lock.
func TestGetAssignedAggregatorsReturnsDefensiveCopy(t *testing.T) {
	topo := NewTopology()
	if err := topo.AssignAggregator("edge-1", []string{"agg-1", "agg-2", "agg-3"}); err != nil {
		t.Fatalf("AssignAggregator: %v", err)
	}

	first, err := topo.GetAssignedAggregators("edge-1")
	if err != nil {
		t.Fatalf("GetAssignedAggregators: %v", err)
	}
	first[0] = "MUTATED"

	second, err := topo.GetAssignedAggregators("edge-1")
	if err != nil {
		t.Fatalf("GetAssignedAggregators: %v", err)
	}
	if second[0] != "agg-1" {
		t.Errorf("aggregator[0] = %q, want %q — caller mutated topology internals", second[0], "agg-1")
	}
}

func TestUpdateReputationClampsToUnitInterval(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("edge-1", EdgeNode)

	topo.UpdateReputation("edge-1", -0.4)
	if got := nodeReputation(topo, "edge-1"); got != 0.6 {
		t.Errorf("Reputation = %v, want 0.6", got)
	}

	topo.UpdateReputation("edge-1", -5.0)
	if got := nodeReputation(topo, "edge-1"); got != 0 {
		t.Errorf("Reputation = %v, want 0 (clamped)", got)
	}

	topo.UpdateReputation("edge-1", 99.0)
	if got := nodeReputation(topo, "edge-1"); got != 1 {
		t.Errorf("Reputation = %v, want 1 (clamped)", got)
	}
}

func TestUpdateReputationUnknownNodeIsNoOp(t *testing.T) {
	topo := NewTopology()

	// Must not panic.
	topo.UpdateReputation("ghost", -1.0)

	if got := topo.GetNodeCount(EdgeNode); got != 0 {
		t.Errorf("EdgeNode count = %d, want 0", got)
	}
}

func TestHealthCheckExcludesLowReputation(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("honest-1", EdgeNode)
	topo.RegisterNode("honest-2", EdgeNode)
	topo.RegisterNode("byzantine-1", EdgeNode)

	// Drive one node below the 0.3 Byzantine threshold.
	topo.UpdateReputation("byzantine-1", -0.8)

	unhealthy := topo.HealthCheck()

	if len(unhealthy) != 1 {
		t.Fatalf("unhealthy = %v, want exactly [byzantine-1]", unhealthy)
	}
	if unhealthy[0] != "byzantine-1" {
		t.Errorf("unhealthy[0] = %q, want %q", unhealthy[0], "byzantine-1")
	}
	if got := topo.GetHealthyNodes(); got != 2 {
		t.Errorf("healthy count = %d, want 2", got)
	}
}

func TestHealthCheckExcludesStaleHeartbeat(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("fresh", EdgeNode)
	topo.RegisterNode("stale", EdgeNode)

	// Backdate one heartbeat past the 30s timeout.
	topo.mu.Lock()
	topo.nodes["stale"].LastHeartbeat = time.Now().Add(-31 * time.Second)
	topo.mu.Unlock()

	unhealthy := topo.HealthCheck()
	if len(unhealthy) != 1 || unhealthy[0] != "stale" {
		t.Fatalf("unhealthy = %v, want [stale]", unhealthy)
	}
}

func TestHealthCheckIsIdempotent(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("byzantine-1", EdgeNode)
	topo.UpdateReputation("byzantine-1", -0.8)

	first := topo.HealthCheck()
	second := topo.HealthCheck()

	if len(first) != 1 || len(second) != 1 {
		t.Fatalf("first = %v, second = %v, want one entry each", first, second)
	}
	if first[0] != second[0] {
		t.Errorf("first[0] = %q, second[0] = %q", first[0], second[0])
	}
}

// A node whose reputation recovers must become healthy again — health is
// recomputed, not latched.
func TestHealthCheckReflectsRecovery(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("node-1", EdgeNode)

	topo.UpdateReputation("node-1", -0.8)
	if unhealthy := topo.HealthCheck(); len(unhealthy) != 1 {
		t.Fatalf("expected node excluded, got %v", unhealthy)
	}

	topo.UpdateReputation("node-1", 1.0)
	if unhealthy := topo.HealthCheck(); len(unhealthy) != 0 {
		t.Fatalf("expected node recovered, got %v", unhealthy)
	}
	if got := topo.GetHealthyNodes(); got != 1 {
		t.Errorf("healthy count = %d, want 1", got)
	}
}

func TestHealthCheckEmptyTopology(t *testing.T) {
	topo := NewTopology()

	unhealthy := topo.HealthCheck()
	if unhealthy == nil {
		t.Error("want an empty non-nil slice, got nil")
	}
	if len(unhealthy) != 0 {
		t.Errorf("unhealthy = %v, want empty", unhealthy)
	}
}

// GetHealthyNodes reports a count derived from cached IsHealthy flags, which
// only HealthCheck refreshes. Before any health check every node is flagged
// healthy at registration.
func TestGetHealthyNodesBeforeHealthCheck(t *testing.T) {
	topo := NewTopology()
	topo.RegisterNode("a", EdgeNode)
	topo.RegisterNode("b", EdgeNode)

	if got := topo.GetHealthyNodes(); got != 2 {
		t.Errorf("healthy count = %d, want 2", got)
	}
}

func TestConcurrentAccessIsRaceFree(t *testing.T) {
	topo := NewTopology()

	var wg sync.WaitGroup
	for i := 0; i < 16; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			id := string(rune('a'+i%8)) + "-node"
			topo.RegisterNode(id, EdgeNode)
			topo.AssignAggregator(id, []string{"agg-1", "agg-2", "agg-3"})
			topo.UpdateReputation(id, -0.05)
			_, _ = topo.GetAssignedAggregators(id)
			topo.HealthCheck()
			topo.GetHealthyNodes()
			topo.GetNodeCount(EdgeNode)
		}(i)
	}
	wg.Wait()

	if got := topo.GetNodeCount(EdgeNode); got != 8 {
		t.Errorf("EdgeNode count = %d, want 8", got)
	}
}

func nodeReputation(topo *Topology, id string) float64 {
	topo.mu.RLock()
	defer topo.mu.RUnlock()
	return topo.nodes[id].Reputation
}
