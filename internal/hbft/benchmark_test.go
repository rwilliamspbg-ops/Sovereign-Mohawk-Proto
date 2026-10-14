package hbft

import "testing"

// The consensus layer had no benchmarks, leaving the critical path of a BFT
// protocol unmeasured. These cover the two entry points that dominate a round:
// MultiKrumSelect inside a committee, and a full multi-tier round.

func benchSimulator(b *testing.B, topo TopologyConfig, dim int) *Simulator {
	b.Helper()
	sim, err := NewSimulator(SimulatorConfig{
		Topology:      topo,
		ByzantineRate: 0.2,
		Adversary:     OutlierAdversary{Magnitude: 100},
		Dimension:     dim,
		Seed:          42,
	})
	if err != nil {
		b.Fatalf("new simulator: %v", err)
	}
	return sim
}

func BenchmarkRunRound_SingleCommittee(b *testing.B) {
	sim := benchSimulator(b, TopologyConfig{Tiers: 1, CommitteesPerTier: 1, NodesPerCommittee: 27}, 4)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := sim.RunRound(); err != nil {
			b.Fatalf("run round: %v", err)
		}
	}
}

func BenchmarkRunRound_MultiTier(b *testing.B) {
	// Matches testTopology(): 3 tiers x 6 committees x 27 nodes = 486 nodes.
	sim := benchSimulator(b, TopologyConfig{Tiers: 3, CommitteesPerTier: 6, NodesPerCommittee: 27}, 4)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := sim.RunRound(); err != nil {
			b.Fatalf("run round: %v", err)
		}
	}
}

func BenchmarkRunRound_HighDimension(b *testing.B) {
	// Larger gradient vectors stress the distance computation in MultiKrumSelect,
	// which is O(n^2 * dimension) per committee.
	sim := benchSimulator(b, TopologyConfig{Tiers: 1, CommitteesPerTier: 1, NodesPerCommittee: 27}, 512)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := sim.RunRound(); err != nil {
			b.Fatalf("run round: %v", err)
		}
	}
}

func BenchmarkRun_ConsecutiveRounds(b *testing.B) {
	sim := benchSimulator(b, TopologyConfig{Tiers: 1, CommitteesPerTier: 2, NodesPerCommittee: 27}, 4)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := sim.Run(5); err != nil {
			b.Fatalf("run: %v", err)
		}
	}
}
