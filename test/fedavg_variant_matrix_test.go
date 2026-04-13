package test

import (
	"fmt"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

func TestFedAvgVariantMatrixProfiles(t *testing.T) {
	t.Parallel()

	type tc struct {
		name          string
		nodes         int
		localEpochs   int
		participation float64
		malicious     float64
		expectFail    bool
	}

	cases := []tc{
		{name: "e1_p100_safe_1500", nodes: 1500, localEpochs: 1, participation: 1.0, malicious: 0.44, expectFail: false},
		{name: "e5_p95_safe_3000", nodes: 3000, localEpochs: 5, participation: 0.95, malicious: 0.44, expectFail: false},
		{name: "e10_p80_safe_5000", nodes: 5000, localEpochs: 10, participation: 0.80, malicious: 0.44, expectFail: false},
		{name: "e1_p100_edge_1500", nodes: 1500, localEpochs: 1, participation: 1.0, malicious: 0.56, expectFail: true},
		{name: "e5_p90_edge_10000", nodes: 10000, localEpochs: 5, participation: 0.90, malicious: 0.56, expectFail: true},
	}

	for _, c := range cases {
		c := c
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()
			active := int(float64(c.nodes) * c.participation)
			if active < 1 {
				active = 1
			}
			malicious := int(float64(active) * c.malicious)
			honest := active - malicious
			if honest < 0 {
				honest = 0
			}

			agg := batch.NewAggregator(&batch.Config{
				TotalNodes:       c.nodes,
				HonestNodes:      honest,
				MaliciousNodes:   malicious,
				RedundancyFactor: maxIntLocal(1, c.localEpochs),
			})
			err := agg.ProcessRound(batch.ModeByzantineMix)
			if c.expectFail && err == nil {
				t.Fatalf("expected failure for %s", c.name)
			}
			if !c.expectFail && err != nil {
				t.Fatalf("expected success for %s, got: %v", c.name, err)
			}

			scenario := fedAvgScenarioFromEnv(c.localEpochs, c.participation)
			expectedPrefix := fmt.Sprintf("fedavg_e%d_p", c.localEpochs)
			if len(scenario) < len(expectedPrefix) || scenario[:len(expectedPrefix)] != expectedPrefix {
				t.Fatalf("unexpected scenario label: %s", scenario)
			}
		})
	}
}

func maxIntLocal(a, b int) int {
	if a > b {
		return a
	}
	return b
}
