package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestSwarmIntegration500To1000Nodes(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name      string
		total     int
		malicious int
	}{
		{name: "swarm_500_nodes", total: 500, malicious: 200},
		{name: "swarm_1000_nodes", total: 1000, malicious: 440},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			h := tc.total - tc.malicious
			agg := batch.NewAggregator(&batch.Config{
				TotalNodes:       tc.total,
				HonestNodes:      h,
				MaliciousNodes:   tc.malicious,
				RedundancyFactor: 10,
			})
			if err := agg.ProcessRound(batch.ModeByzantineMix); err != nil {
				t.Fatalf("expected healthy swarm round to pass: %v", err)
			}
			if !agg.Verified {
				t.Fatal("expected round verification to be true")
			}
			if agg.FilteredCount != tc.malicious {
				t.Fatalf("filtered count mismatch: got %d want %d", agg.FilteredCount, tc.malicious)
			}
		})
	}
}

func TestByzantineEdgeCasesOver55PercentMalicious(t *testing.T) {
	t.Parallel()

	cases := []struct {
		name      string
		total     int
		malicious int
	}{
		{name: "byzantine_500_nodes_56_percent", total: 500, malicious: 280},
		{name: "byzantine_1000_nodes_56_percent", total: 1000, malicious: 560},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			h := tc.total - tc.malicious
			agg := batch.NewAggregator(&batch.Config{
				TotalNodes:       tc.total,
				HonestNodes:      h,
				MaliciousNodes:   tc.malicious,
				RedundancyFactor: 10,
			})
			if err := agg.ProcessRound(batch.ModeByzantineMix); err == nil {
				t.Fatal("expected >55% malicious scenario to fail resilience checks")
			}
		})
	}
}

func TestHardwareAgnosticBackendProfiles(t *testing.T) {
	cases := []struct {
		name     string
		backend  string
		npuAvail string
	}{
		{name: "cpu_profile", backend: "cpu", npuAvail: "false"},
		{name: "cuda_profile", backend: "cuda", npuAvail: "false"},
		{name: "npu_profile", backend: "npu", npuAvail: "true"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			// This test mutates env vars, so it intentionally avoids t.Parallel.
			t.Setenv("MOHAWK_ACCELERATOR_BACKEND", tc.backend)
			t.Setenv("MOHAWK_NPU_AVAILABLE", tc.npuAvail)

			profile := accelerator.BuildAutoTuneProfile(8192)
			if profile.RecommendedWorker < 1 {
				t.Fatalf("invalid worker recommendation: %d", profile.RecommendedWorker)
			}
			if profile.PreferredFormat != "fp16" && profile.PreferredFormat != "int8" {
				t.Fatalf("unexpected gradient format: %s", profile.PreferredFormat)
			}
			if len(profile.DetectedDevices) == 0 {
				t.Fatal("expected at least one detected device")
			}
		})
	}
}
