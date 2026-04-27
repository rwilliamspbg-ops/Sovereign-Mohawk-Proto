//go:build cgo

package main

import (
	"encoding/json"
	"strings"
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestAggregateUpdatesCore_ListPayload(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	updates := []aggregateUpdatePayload{
		{NodeID: "n1", Gradient: []float64{0.1, 0.2, 0.3}},
		{NodeID: "n2", Gradient: []float64{0.11, 0.19, 0.29}},
		{NodeID: "n3", Gradient: []float64{0.09, 0.21, 0.31}},
	}
	payload, err := json.Marshal(updates)
	if err != nil {
		t.Fatalf("marshal updates: %v", err)
	}

	result, err := aggregateUpdatesCore(string(payload), aggregator)
	if err != nil {
		t.Fatalf("aggregateUpdatesCore failed: %v", err)
	}
	if result["multi_krum"] != false {
		t.Fatalf("expected multi_krum=false, got %v", result["multi_krum"])
	}
	if got, ok := result["count"].(int); !ok || got != len(updates) {
		t.Fatalf("expected count=%d, got %v", len(updates), result["count"])
	}
}

func TestAggregateUpdatesCore_WrappedPayloadWithMultiKrum(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	wrapped := aggregateUpdatesRequest{
		Updates: []aggregateUpdatePayload{
			{NodeID: "n1", Gradient: []float64{0.1, 0.2, 0.3}},
			{NodeID: "n2", Gradient: []float64{0.11, 0.19, 0.29}},
			{NodeID: "n3", Gradient: []float64{0.09, 0.21, 0.31}},
			{NodeID: "n4", Gradient: []float64{5.0, 5.0, 5.0}},
			{NodeID: "n5", Gradient: []float64{0.1, 0.2, 0.28}},
		},
		ByzantineF: 1,
		MultiKrumM: 3,
	}
	payload, err := json.Marshal(wrapped)
	if err != nil {
		t.Fatalf("marshal wrapped payload: %v", err)
	}

	result, err := aggregateUpdatesCore(string(payload), aggregator)
	if err != nil {
		t.Fatalf("aggregateUpdatesCore failed: %v", err)
	}
	if result["multi_krum"] != true {
		t.Fatalf("expected multi_krum=true, got %v", result["multi_krum"])
	}

	selected, ok := result["selected_count"].(int)
	if !ok {
		t.Fatalf("selected_count should be int, got %T", result["selected_count"])
	}
	if selected != 3 {
		t.Fatalf("expected selected_count=3, got %d", selected)
	}
}

func TestAggregateUpdatesCore_InvalidPayload(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	_, err := aggregateUpdatesCore("{not-json", aggregator)
	if err == nil {
		t.Fatalf("expected parse error for malformed payload")
	}
	if !strings.Contains(strings.ToLower(err.Error()), "parse") {
		t.Fatalf("expected parse-related error, got: %v", err)
	}
}

func TestAggregateUpdatesCore_EmptyPayload(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	payload, err := json.Marshal([]aggregateUpdatePayload{})
	if err != nil {
		t.Fatalf("marshal empty payload: %v", err)
	}
	_, err = aggregateUpdatesCore(string(payload), aggregator)
	if err == nil {
		t.Fatalf("expected error for empty gradient batch")
	}
	if !strings.Contains(strings.ToLower(err.Error()), "empty") {
		t.Fatalf("expected empty-batch error, got: %v", err)
	}
}

func TestAggregateUpdatesCore_AdvancedAsyncOptions(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	wrapped := aggregateUpdatesRequest{
		Updates: []aggregateUpdatePayload{
			{NodeID: "n1", Gradient: []float64{0.1, 0.2, 0.3}, AgeSec: 2, ReliabilityScore: 0.95, LatencyMS: 25},
			{NodeID: "n2", Gradient: []float64{0.11, 0.19, 0.29}, AgeSec: 1, ReliabilityScore: 0.90, LatencyMS: 35},
			{NodeID: "n3", Gradient: []float64{0.09, 0.21, 0.31}, AgeSec: 8, ReliabilityScore: 0.85, LatencyMS: 50},
			{NodeID: "n4", Gradient: []float64{5.0, 5.0, 5.0}, AgeSec: 0.2, ReliabilityScore: 0.99, LatencyMS: 10},
		},
		ByzantineF:            1,
		MultiKrumM:            2,
		SemiAsyncQuorum:       0.85,
		HierarchicalGroupSize: 2,
		WeightedTrimFraction:  0.10,
		StalenessHalfLifeSec:  10,
		AdaptiveQuorumMin:     0.5,
		AdaptiveQuorumMax:     0.95,
		AdaptiveTargetP95Ms:   20,
		BufferedWindowSize:    3,
		UtilityTopFraction:    0.75,
		EnableAsyncFallback:   true,
	}
	payload, err := json.Marshal(wrapped)
	if err != nil {
		t.Fatalf("marshal wrapped payload: %v", err)
	}

	result, err := aggregateUpdatesCore(string(payload), aggregator)
	if err != nil {
		t.Fatalf("aggregateUpdatesCore failed: %v", err)
	}

	if _, ok := result["effective_quorum"].(float64); !ok {
		t.Fatalf("effective_quorum should be float64, got %T", result["effective_quorum"])
	}
	if _, ok := result["active_nodes"].(int); !ok {
		t.Fatalf("active_nodes should be int, got %T", result["active_nodes"])
	}
}

func TestAggregateUpdatesCore_MaxUpdatesAdmission(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	t.Setenv("MOHAWK_AGGREGATE_MAX_UPDATES", "2")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	wrapped := aggregateUpdatesRequest{
		Updates: []aggregateUpdatePayload{
			{NodeID: "n1", Gradient: []float64{0.1, 0.2}},
			{NodeID: "n2", Gradient: []float64{0.2, 0.3}},
			{NodeID: "n3", Gradient: []float64{0.3, 0.4}},
		},
	}
	payload, err := json.Marshal(wrapped)
	if err != nil {
		t.Fatalf("marshal wrapped payload: %v", err)
	}

	result, err := aggregateUpdatesCore(string(payload), aggregator)
	if err != nil {
		t.Fatalf("aggregateUpdatesCore failed: %v", err)
	}
	if got, ok := result["count"].(int); !ok || got != 2 {
		t.Fatalf("expected count=2 after max-update admission, got %v", result["count"])
	}
}

func TestAggregateUpdatesCore_MaxAgeAdmission(t *testing.T) {
	t.Setenv("MOHAWK_DP_SIGMA", "5")
	t.Setenv("MOHAWK_AGGREGATE_MAX_AGE_SEC", "3")
	aggregator := internalpkg.NewAggregator(internalpkg.Regional)
	wrapped := aggregateUpdatesRequest{
		Updates: []aggregateUpdatePayload{
			{NodeID: "n1", Gradient: []float64{0.1, 0.2}, AgeSec: 2},
			{NodeID: "n2", Gradient: []float64{0.2, 0.3}, AgeSec: 9},
			{NodeID: "n3", Gradient: []float64{0.3, 0.4}, AgeSec: 1},
		},
	}
	payload, err := json.Marshal(wrapped)
	if err != nil {
		t.Fatalf("marshal wrapped payload: %v", err)
	}

	result, err := aggregateUpdatesCore(string(payload), aggregator)
	if err != nil {
		t.Fatalf("aggregateUpdatesCore failed: %v", err)
	}
	if got, ok := result["count"].(int); !ok || got != 2 {
		t.Fatalf("expected count=2 after age admission, got %v", result["count"])
	}
}
