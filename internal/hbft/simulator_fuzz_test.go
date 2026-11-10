package hbft

import (
	"testing"
)

func FuzzNewSimulator(f *testing.F) {
	f.Add(1, 1, 1, 7, 2)
	f.Fuzz(func(t *testing.T, tiers, committees, nodes, n, fcount int) {
		if tiers <= 0 || tiers > 3 || committees <= 0 || committees > 3 || nodes <= 0 || nodes > 64 {
			t.Skip()
		}
		cfg := SimulatorConfig{
			Topology: TopologyConfig{
				Tiers:             tiers,
				CommitteesPerTier: committees,
				NodesPerCommittee: nodes,
			},
			ByzantineRate: 0.1,
			Adversary:     OutlierAdversary{},
			Dimension:     2,
			Seed:          1,
		}
		_, err := NewSimulator(cfg)
		// Either accepts or rejects based on safety; must not panic.
		_ = err
	})
}
