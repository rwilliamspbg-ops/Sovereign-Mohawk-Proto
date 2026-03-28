package main

import (
	"encoding/json"
	"strings"
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestAggregateUpdatesCore_ListPayload(t *testing.T) {
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
