// Copyright 2026 Sovereign-Mohawk Core Team
// License: Apache 2.0
// Stress Test: Measure MRC transport throughput and latency

package main

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/transport"
)

// StressTestConfig holds parameters for running a transport stress test.
type StressTestConfig struct {
	Name         string
	NumPaths     int
	ChunkSize    int
	Duration     time.Duration
	ParallelSend int
}

func main() {
	fmt.Println("🔥 MRC Transport Stress Test")
	fmt.Println("============================")
	fmt.Println()

	ctx := context.Background()

	// Test configurations
	configs := []StressTestConfig{
		{Name: "Conservative", NumPaths: 4, ChunkSize: 1000, Duration: 5 * time.Second, ParallelSend: 10},
		{Name: "Moderate", NumPaths: 4, ChunkSize: 5000, Duration: 5 * time.Second, ParallelSend: 50},
		{Name: "Aggressive", NumPaths: 4, ChunkSize: 10000, Duration: 5 * time.Second, ParallelSend: 100},
	}

	for _, cfg := range configs {
		runStressTest(ctx, cfg)
		fmt.Println()
	}

	fmt.Println("✅ Stress tests complete")
}

func runStressTest(ctx context.Context, cfg StressTestConfig) {
	fmt.Printf("📊 Test: %s\n", cfg.Name)
	fmt.Printf("   Paths: %d, Chunk size: %d, Duration: %v, Parallel: %d\n", cfg.NumPaths, cfg.ChunkSize, cfg.Duration, cfg.ParallelSend)
	fmt.Println()

	// Create transport
	adapter := transport.NewMRCAdapter("stress-test", cfg.NumPaths)

	// Register destinations
	for i := 0; i < 5; i++ {
		adapter.RegisterDestination(fmt.Sprintf("agg-%d", i))
	}

	// Measurement variables
	var totalChunks int64
	var totalErrors int64
	minLatency := 1 * time.Hour
	var maxLatency time.Duration
	var mu sync.Mutex

	// Start health monitor
	go adapter.HealthMonitor(ctx)

	// Stress test loop
	startTime := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), cfg.Duration)
	defer cancel()

	var wg sync.WaitGroup

	// Parallel senders
	for sender := 0; sender < cfg.ParallelSend; sender++ {
		wg.Add(1)
		go func(senderID int) {
			defer wg.Done()

			chunkIdx := 0
			for {
				select {
				case <-ctx.Done():
					return
				default:
					chunk := transport.GradientChunk{
						ID:      fmt.Sprintf("stress-%d-%d", senderID, chunkIdx),
						NodeID:  fmt.Sprintf("sender-%d", senderID),
						Index:   chunkIdx % 100,
						Total:   100,
						Payload: make([]float32, cfg.ChunkSize),
					}

					dest := fmt.Sprintf("agg-%d", chunkIdx%5)
					sendStart := time.Now()

					err := adapter.SendChunk(ctx, dest, chunk)

					latency := time.Since(sendStart)

					mu.Lock()
					totalChunks++
					if err != nil {
						totalErrors++
					} else {
						if latency < minLatency {
							minLatency = latency
						}
						if latency > maxLatency {
							maxLatency = latency
						}
					}
					mu.Unlock()

					chunkIdx++
				}
			}
		}(sender)
	}

	wg.Wait()
	elapsed := time.Since(startTime)

	// Report results
	mu.Lock()
	successCount := totalChunks - totalErrors
	mu.Unlock()

	throughput := float64(totalChunks) / elapsed.Seconds()
	successRate := float64(successCount) * 100 / float64(totalChunks)

	fmt.Printf("   Results:\n")
	fmt.Printf("   Total chunks: %d\n", totalChunks)
	fmt.Printf("   Throughput: %.0f chunks/sec\n", throughput)
	fmt.Printf("   Success rate: %.1f%%\n", successRate)
	fmt.Printf("   Latency - Min: %.2fms, Max: %.2fms\n", minLatency.Seconds()*1000, maxLatency.Seconds()*1000)
	fmt.Printf("   Errors: %d\n", totalErrors)

	// Health status
	health := adapter.Health()
	healthyPaths := 0
	for _, h := range health {
		if h.IsHealthy {
			healthyPaths++
		}
	}
	fmt.Printf("   Healthy paths: %d/%d\n", healthyPaths, len(health))

	_ = adapter.Close()
}
