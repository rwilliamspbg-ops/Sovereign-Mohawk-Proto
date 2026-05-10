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

// flushPartialAggregation triggers Byzantine filtering and aggregation
func (a *StreamingAggregator) flushPartialAggregation() {
	a.mu.Lock()

	// Collect assembled gradients
	var assemblies []*ChunkAssembly
	var nodeIDs []string
	
	for nodeID, assembly := range a.chunkBuffers {
		if len(assembly.chunks) == assembly.total {
			assemblies = append(assemblies, assembly)
			nodeIDs = append(nodeIDs, nodeID)
		}
	}

	// Need minimum quorum for Byzantine filtering
	if len(assemblies) < a.quorumSize {
		a.mu.Unlock()
		return
	}

	// Convert chunk assemblies to full gradient tensors
	gradients := make([][]float64, len(assemblies))
	for i, assembly := range assemblies {
		gradient := a.assembleGradientFromChunks(assembly)
		gradients[i] = gradient
	}
	a.mu.Unlock()

	// Apply MultiKrum Byzantine filtering
	byzantineF := len(assemblies) / 3 // Assume up to 1/3 Byzantine attackers
	selected, selectedGradients, scores, err := a.applyMultiKrumFiltering(gradients, byzantineF)
	
	if err != nil {
		log.Printf("WARNING: MultiKrum filtering failed: %v", err)
		// Fall back to simple mean aggregation
		selected = a.getFallbackSelection(len(gradients))
		selectedGradients = make([][]float64, len(selected))
		for i, idx := range selected {
			selectedGradients[i] = gradients[idx]
		}
	}

	// Aggregate filtered gradients
	aggregatedResult := a.aggregateGradients(selectedGradients)

	// Track results
	a.mu.Lock()
	a.totalGradients += int64(len(selected))
	
	// Compute privacy loss via RDP Accountant
	epsilon := a.accountant.Rdp2Eps(1.0, 1e-5)
	
	a.mu.Unlock()

	log.Printf("[%s streaming-aggregator] flushed %d gradients (selected %d after MultiKrum, scores: %v, epsilon: %.4f)",
		a.tier, len(assemblies), len(selected), scores, epsilon)

	// Clean up processed assemblies
	a.mu.Lock()
	for i, nodeID := range nodeIDs {
		if i < len(selected) {
			delete(a.chunkBuffers, nodeID)
		}
	}
	a.mu.Unlock()
}

// assembleGradientFromChunks reconstructs full gradient from chunks
func (a *StreamingAggregator) assembleGradientFromChunks(assembly *ChunkAssembly) []float64 {
	// Calculate total dimension
	totalDim := 0
	for _, chunk := range assembly.chunks {
		totalDim += len(chunk.GradientData)
	}

	gradient := make([]float64, totalDim)
	offset := 0
	for i := 0; i < assembly.total; i++ {
		if chunk, ok := assembly.chunks[i]; ok {
			copy(gradient[offset:], chunk.GradientData)
			offset += len(chunk.GradientData)
		}
	}
	return gradient
}

// applyMultiKrumFiltering uses MultiKrum algorithm for Byzantine resilience
func (a *StreamingAggregator) applyMultiKrumFiltering(gradients [][]float64, f int) ([]int, [][]float64, []float64, error) {
	if len(gradients) <= 2*f+2 {
		// Not enough gradients for Byzantine tolerance, return all
		indices := make([]int, len(gradients))
		for i := range indices {
			indices[i] = i
		}
		scores := make([]float64, len(gradients))
		return indices, gradients, scores, nil
	}

	// Apply MultiKrum with Byzantine parameter f
	selected, scores, err := MultiKrumSelect(gradients, f, 0) // m=0 uses default
	if err != nil {
		return nil, nil, nil, err
	}

	// Extract selected gradients
	selectedGradients := make([][]float64, len(selected))
	for i, idx := range selected {
		selectedGradients[i] = gradients[idx]
	}

	return selected, selectedGradients, scores, nil
}

// aggregateGradients computes mean of multiple gradients
func (a *StreamingAggregator) aggregateGradients(gradients [][]float64) []float64 {
	if len(gradients) == 0 {
		return nil
	}

	dim := len(gradients[0])
	result := make([]float64, dim)

	for _, g := range gradients {
		if len(g) != dim {
			log.Printf("WARNING: gradient dimension mismatch: %d != %d", len(g), dim)
			continue
		}
		for i := range result {
			result[i] += g[i]
		}
	}

	// Average
	if len(gradients) > 0 {
		scale := 1.0 / float64(len(gradients))
		for i := range result {
			result[i] *= scale
		}
	}

	return result
}

// getFallbackSelection returns all indices when Byzantine filtering fails
func (a *StreamingAggregator) getFallbackSelection(count int) []int {
	indices := make([]int, count)
	for i := range indices {
		indices[i] = i
	}
	return indices

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
