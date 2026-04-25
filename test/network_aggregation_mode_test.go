package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
)

func TestParseAggregationModeAliases(t *testing.T) {
	if got := network.ParseAggregationMode("tfhe"); got != network.AggregationModeFHEThreshold {
		t.Fatalf("expected tfhe alias -> %q, got %q", network.AggregationModeFHEThreshold, got)
	}
	if got := network.ParseAggregationMode("plaintext"); got != network.AggregationModePlaintext {
		t.Fatalf("expected plaintext mode, got %q", got)
	}
}

func TestConfigValidateRejectsUnknownAggregationMode(t *testing.T) {
	cfg := network.DefaultConfig(0)
	cfg.AggregationMode = network.AggregationMode("invalid")
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected unknown aggregation mode to fail validation")
	}
}
