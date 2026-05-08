// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Streaming Aggregator: Accepts unordered chunks instead of full tensors

package internal

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/transport"
)

// ChunkAssembly buffers gradient chunks until complete
type ChunkAssembly struct {
	chunks    map[int]transport.GradientChunk
	total     int
	assembled time.Time
	nodeID    string
}

// StreamingAggregator accepts unordered chunks instead of full tensors
type StreamingAggregator struct {
	tier               Tier
	trans              transport.Transport
	chunkBuffers       map[string]*ChunkAssembly // nodeID -> assembly
	mu                 sync.RWMutex
	batchTimeout       time.Duration
	quorumSize         int
	accountant         *RDPAccountant
	liveness           *StragglerMonitor
	totalChunksIngested int64
	totalGradients      int64
}

// NewStreamingAggregator creates a streaming aggregator
func NewStreamingAggregator(t Tier, trans transport.Transport) *StreamingAggregator {
	return &StreamingAggregator{
		tier:         t,
		trans:        trans,
		chunkBuffers: make(map[string]*ChunkAssembly),
		batchTimeout: 500 * time.Millisecond,
		quorumSize:   getTierQuorum(t),
		accountant:   NewRDPAccountant(2.0, 1e-7),
		liveness:     NewStragglerMonitor(),
	}
}

// IngestChunk is the hot path - non-blocking chunk ingestion
func (a *StreamingAggregator) IngestChunk(chunk transport.GradientChunk) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	a.totalChunksIngested++

	// Create assembly buffer if needed
	if a.chunkBuffers[chunk.NodeID] == nil {
		a.chunkBuffers[chunk.NodeID] = &ChunkAssembly{
			chunks: make(map[int]transport.GradientChunk),
			total:  chunk.Total,
			nodeID: chunk.NodeID,
		}
	}

	assembly := a.chunkBuffers[chunk.NodeID]
	assembly.chunks[chunk.Index] = chunk

	// Check if tensor is complete
	if len(assembly.chunks) == assembly.total {
		a.totalGradients++
		assembly.assembled = time.Now()
		// In production: trigger aggregation here
	}

	return nil
}

// RunAggregationLoop consumes chunks from transport
func (a *StreamingAggregator) RunAggregationLoop(ctx context.Context) {
	chunkChan, _ := a.trans.Receive(ctx)
	ticker := time.NewTicker(a.batchTimeout)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case chunk := <-chunkChan:
			if err := a.IngestChunk(chunk); err != nil {
				log.Printf("Chunk ingestion error: %v", err)
			}
		case <-ticker.C:
			a.flushPartialAggregation()
		}
	}
}

// flushPartialAggregation triggers even if not all chunks arrived
func (a *StreamingAggregator) flushPartialAggregation() {
	a.mu.Lock()
	defer a.mu.Unlock()

	assembled := 0
	for _, assembly := range a.chunkBuffers {
		if len(assembly.chunks) > 0 {
			assembled++
		}
	}

	if assembled >= a.quorumSize {
		// In production: trigger aggregation on partial data
		_ = assembled
	}
}

// GetStats returns aggregation statistics
func (a *StreamingAggregator) GetStats() map[string]interface{} {
	a.mu.RLock()
	defer a.mu.RUnlock()

	return map[string]interface{}{
		"total_chunks_ingested": a.totalChunksIngested,
		"total_gradients":       a.totalGradients,
		"active_assemblies":     len(a.chunkBuffers),
	}
}

// getTierQuorum returns minimum nodes for Byzantine tolerance
func getTierQuorum(t Tier) int {
	switch t {
	case Regional:
		return 30 // 30% of nodes
	case Continental:
		return 300
	case Global:
		return 3000
	}
	return 1
}

// Remove duplicate type declarations - using from aggregator.go
// type Tier int
// const (
//	Regional    Tier = 1
//	Continental Tier = 2
//	Global      Tier = 3
// )
