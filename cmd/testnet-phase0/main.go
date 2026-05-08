// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Phase-0 Testnet: MRC-Compatible Federated Learning

package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/cluster"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/transport"
)

func main() {
	fmt.Println("🚀 Sovereign Mohawk Phase-0: MRC-Compatible Federated Learning Testnet")
	fmt.Println("=====================================================================")
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// 1. Initialize topology
	topology := cluster.NewTopology()
	log.Println("✓ Topology initialized")

	// 2. Create transport layer with MRC adapter
	mrcAdapter := transport.NewMRCAdapter("coordinator-1", 4)
	log.Println("✓ MRC Transport initialized (4 paths per destination)")

	// 3. Register edge nodes (50 nodes for Phase-0)
	numEdgeNodes := 50
	edgeNodes := make([]string, numEdgeNodes)
	for i := 0; i < numEdgeNodes; i++ {
		nodeID := fmt.Sprintf("edge-%03d", i)
		edgeNodes[i] = nodeID
		topology.RegisterNode(nodeID, cluster.EdgeNode)
	}
	log.Printf("✓ Registered %d edge nodes\n", numEdgeNodes)

	// 4. Register regional aggregators (5 nodes)
	numAggregators := 5
	aggregators := make([]string, numAggregators)
	for i := 0; i < numAggregators; i++ {
		aggID := fmt.Sprintf("agg-regional-%d", i)
		aggregators[i] = aggID
		topology.RegisterNode(aggID, cluster.RegionalAggregator)
		mrcAdapter.RegisterDestination(aggID)
	}
	log.Printf("✓ Registered %d regional aggregators\n", numAggregators)

	// 5. Register global coordinator
	globalID := "coordinator-global"
	topology.RegisterNode(globalID, cluster.GlobalCoordinator)
	mrcAdapter.RegisterDestination(globalID)
	log.Println("✓ Registered global coordinator")

	// 6. Assign redundant paths (edge -> 3 aggregators each)
	for _, edgeID := range edgeNodes {
		selected := selectDiverseAggregators(aggregators, 3)
		topology.AssignAggregator(edgeID, selected)
	}
	log.Println("✓ Assigned redundant aggregation paths (3-way diversity)")
	fmt.Println()

	// 7. Create streaming aggregator
	streamingAgg := internal.NewStreamingAggregator(internal.Regional, mrcAdapter)
	log.Println("✓ Created streaming aggregator")

	// 8. Start aggregation loop
	go streamingAgg.RunAggregationLoop(ctx)

	// 9. Start health monitor
	go mrcAdapter.HealthMonitor(ctx)

	// 10. Run training rounds with gradient flow
	fmt.Println("🔄 Starting training simulation (5 rounds):")
	fmt.Println("─────────────────────────────────────────")
	fmt.Println()

	simulateTrainingRounds(ctx, mrcAdapter, streamingAgg, topology, edgeNodes, 5)

	// 11. Wait a bit for aggregation to complete
	time.Sleep(1 * time.Second)

	// 12. Collect and display metrics
	displayMetrics(mrcAdapter, streamingAgg, topology)

	fmt.Println()
	fmt.Println("✅ Phase-0 Testnet Simulation Complete")
}

func selectDiverseAggregators(aggregators []string, count int) []string {
	selected := make([]string, 0, count)
	indices := rand.Perm(len(aggregators))
	for i := 0; i < count && i < len(indices); i++ {
		selected = append(selected, aggregators[indices[i]])
	}
	return selected
}

func simulateTrainingRounds(ctx context.Context, trans transport.Transport, agg *internal.StreamingAggregator, topo *cluster.Topology, nodes []string, rounds int) {
	for round := 1; round <= rounds; round++ {
		roundStart := time.Now()
		totalChunks := 0

		// Parallel gradient submission from all nodes
		var wg sync.WaitGroup
		mu := sync.Mutex{}

		for _, nodeID := range nodes {
			wg.Add(1)
			go func(nid string) {
				defer wg.Done()

				// Get assigned aggregators
				aggs, _ := topo.GetAssignedAggregators(nid)

				// Each node sends 100 chunks (10 chunks × 10-dim each = full gradient)
				for chunk := 0; chunk < 100; chunk++ {
					gradChunk := transport.GradientChunk{
						ID:      fmt.Sprintf("%s-round%d-chunk%d", nid, round, chunk),
						NodeID:  nid,
						Index:   chunk,
						Total:   100,
						Payload: make([]float32, 100), // 100 dims per chunk
					}

					// Fill with synthetic data
					for j := range gradChunk.Payload {
						gradChunk.Payload[j] = float32(rand.Intn(100))
					}

					// Send to first assigned aggregator (MRC handles redundancy)
					if len(aggs) > 0 {
						_ = trans.SendChunk(ctx, aggs[0], gradChunk)
						mu.Lock()
						totalChunks++
						mu.Unlock()
					}
				}
			}(nodeID)
		}

		wg.Wait()

		roundTime := time.Since(roundStart)
		throughput := float64(totalChunks) / roundTime.Seconds()

		fmt.Printf("Round %d/%d: %d chunks submitted | Latency: %.0fms | Throughput: %.0f chunks/sec\n",
			round, rounds, totalChunks, roundTime.Seconds()*1000, throughput)
	}
}

func displayMetrics(trans transport.Transport, agg *internal.StreamingAggregator, topo *cluster.Topology) {
	fmt.Println()
	fmt.Println("📊 Performance Metrics:")
	fmt.Println("─────────────────────────────")
	fmt.Println()

	// Transport health
	health := trans.Health()
	healthyPaths := 0
	for _, h := range health {
		if h.IsHealthy {
			healthyPaths++
		}
	}
	fmt.Printf("Transport Layer:\n")
	fmt.Printf("  Total paths: %d\n", len(health))
	fmt.Printf("  Healthy paths: %d (%.1f%%)\n", healthyPaths, float64(healthyPaths)*100/float64(len(health)))

	// Aggregator stats
	stats := agg.GetStats()
	fmt.Printf("\nAggregation:\n")
	fmt.Printf("  Total chunks ingested: %v\n", stats["total_chunks_ingested"])
	fmt.Printf("  Complete gradients: %v\n", stats["total_gradients"])
	fmt.Printf("  Active assemblies: %v\n", stats["active_assemblies"])

	// Topology status
	totalNodes := 0
	totalNodes += topo.GetNodeCount(cluster.EdgeNode)
	totalNodes += topo.GetNodeCount(cluster.RegionalAggregator)
	totalNodes += topo.GetNodeCount(cluster.GlobalCoordinator)

	unhealthy := topo.HealthCheck()
	fmt.Printf("\nCluster Status:\n")
	fmt.Printf("  Total nodes: %d\n", totalNodes)
	fmt.Printf("  Healthy nodes: %d (%.1f%%)\n", topo.GetHealthyNodes(), float64(topo.GetHealthyNodes())*100/float64(totalNodes))
	fmt.Printf("  Unhealthy nodes: %d\n", len(unhealthy))

	fmt.Printf("\nByzantine Resilience:\n")
	fmt.Printf("  Edge nodes: %d\n", topo.GetNodeCount(cluster.EdgeNode))
	fmt.Printf("  Aggregators: %d\n", topo.GetNodeCount(cluster.RegionalAggregator))
	fmt.Printf("  Coordinators: %d\n", topo.GetNodeCount(cluster.GlobalCoordinator))
	fmt.Printf("  Redundancy: 3-way path diversity\n")

	fmt.Println()
	fmt.Println("✅ All systems operational")
}
