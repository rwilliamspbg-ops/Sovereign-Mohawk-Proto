// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// MRC Adapter: Multi-path Packet Spraying Transport

package transport

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"
)

// MRCAdapter implements Transport with MRC-like multi-path packet spraying
// Simulates OpenAI's MRC without requiring specialized hardware
type MRCAdapter struct {
	nodeID      string
	paths       map[string]*MRCPath   // pathID -> path
	pathsByDest map[string][]*MRCPath // destination -> all paths
	mu          sync.RWMutex
	inbox       chan GradientChunk
	done        chan struct{}
	numPaths    int
	logger      *log.Logger
}

// MRCPath represents a virtual path to a destination
// Maps to a logical route across network fabric
type MRCPath struct {
	ID             string
	DestinationID  string
	Latency        time.Duration
	PacketLoss     float64
	Score          float64 // Health score (0.0-1.0)
	LastHealthTime time.Time
	SuccessCount   int64
	FailureCount   int64
	mu             sync.RWMutex
}

// NewMRCAdapter creates a multi-path transport adapter
func NewMRCAdapter(nodeID string, numPaths int) *MRCAdapter {
	if numPaths < 1 {
		numPaths = 4
	}
	if numPaths > 16 {
		numPaths = 16
	}

	return &MRCAdapter{
		nodeID:      nodeID,
		paths:       make(map[string]*MRCPath),
		pathsByDest: make(map[string][]*MRCPath),
		inbox:       make(chan GradientChunk, 2000),
		done:        make(chan struct{}),
		numPaths:    numPaths,
	}
}

// RegisterDestination creates multiple virtual paths to a destination
func (m *MRCAdapter) RegisterDestination(destID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.pathsByDest[destID]; exists {
		return // Already registered
	}

	paths := make([]*MRCPath, m.numPaths)
	for i := 0; i < m.numPaths; i++ {
		pathID := fmt.Sprintf("%s->%s[%d]", m.nodeID, destID, i)
		path := &MRCPath{
			ID:             pathID,
			DestinationID:  destID,
			Score:          1.0,
			LastHealthTime: time.Now(),
			Latency:        time.Duration(10+rand.Intn(50)) * time.Millisecond,
			PacketLoss:     0.0,
		}
		paths[i] = path
		m.paths[pathID] = path
	}

	m.pathsByDest[destID] = paths
}

// SendChunk implements packet spraying: send across multiple paths concurrently
// This is the core MRC behavior: redundancy + speed
func (m *MRCAdapter) SendChunk(ctx context.Context, dest string, chunk GradientChunk) error {
	m.mu.RLock()
	relevantPaths, exists := m.pathsByDest[dest]
	m.mu.RUnlock()

	if !exists || len(relevantPaths) == 0 {
		return fmt.Errorf("no paths to destination %s", dest)
	}

	// Select best 2-4 paths based on health score
	selectedPaths := m.selectBestPaths(relevantPaths, 3)

	if len(selectedPaths) == 0 {
		return fmt.Errorf("all paths to %s are unhealthy", dest)
	}

	// Spray chunks across selected paths (concurrent)
	var wg sync.WaitGroup
	successCount := 0
	mu := sync.Mutex{}

	for _, path := range selectedPaths {
		wg.Add(1)
		go func(p *MRCPath) {
			defer wg.Done()

			// Simulate network delay based on path latency
			select {
			case <-ctx.Done():
				p.recordFailure()
				return
			case <-time.After(p.Latency):
				// Path succeeded
				p.recordSuccess()
				mu.Lock()
				successCount++
				mu.Unlock()
			}
		}(path)
	}

	wg.Wait()

	// At least one path must succeed (MRC guarantee)
	if successCount == 0 {
		return fmt.Errorf("all paths failed to %s", dest)
	}

	return nil
}

// selectBestPaths returns top-N paths by health score
func (m *MRCAdapter) selectBestPaths(paths []*MRCPath, maxCount int) []*MRCPath {
	if len(paths) <= maxCount {
		return paths
	}

	// Sort by score (descending)
	selected := make([]*MRCPath, 0, maxCount)
	scores := make([]float64, len(paths))

	for i, p := range paths {
		p.mu.RLock()
		scores[i] = p.Score
		p.mu.RUnlock()
	}

	// Simple selection: pick top scorers
	indices := make([]int, 0, len(paths))
	for i := range paths {
		indices = append(indices, i)
	}

	// Bubble-sort top maxCount
	for i := 0; i < maxCount && i < len(indices); i++ {
		for j := i + 1; j < len(indices); j++ {
			if scores[indices[j]] > scores[indices[i]] {
				indices[i], indices[j] = indices[j], indices[i]
			}
		}
		selected = append(selected, paths[indices[i]])
	}

	return selected
}

// Receive returns the inbox channel for gradient chunks
func (m *MRCAdapter) Receive(ctx context.Context) (<-chan GradientChunk, error) {
	// In real implementation, listen on network
	// For now, just return inbox
	return m.inbox, nil
}

// Health returns status of all paths
func (m *MRCAdapter) Health() []TransportHealth {
	m.mu.RLock()
	defer m.mu.RUnlock()

	health := make([]TransportHealth, 0, len(m.paths))
	for _, path := range m.paths {
		path.mu.RLock()
		h := TransportHealth{
			PathID:     path.ID,
			Latency:    path.Latency,
			PacketLoss: path.PacketLoss,
			IsHealthy:  path.Score > 0.5,
			LastSeen:   path.LastHealthTime,
		}
		path.mu.RUnlock()
		health = append(health, h)
	}

	return health
}

// HealthMonitor continuously updates path health metrics
func (m *MRCAdapter) HealthMonitor(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-m.done:
			return
		case <-ticker.C:
			m.updatePathHealth()
		}
	}
}

func (m *MRCAdapter) updatePathHealth() {
	m.mu.RLock()
	paths := m.paths
	m.mu.RUnlock()

	for _, path := range paths {
		path.mu.Lock()

		// Calculate packet loss from success/failure ratio
		total := path.SuccessCount + path.FailureCount
		if total > 0 {
			path.PacketLoss = float64(path.FailureCount) / float64(total)
		}

		// Update score: decay old scores, integrate new loss
		if path.PacketLoss > 0.2 {
			path.Score *= 0.9 // Penalize lossy paths
		} else if path.PacketLoss < 0.05 {
			path.Score = 1.0 // Reward healthy paths
		}

		if path.Score < 0 {
			path.Score = 0
		}

		path.LastHealthTime = time.Now()
		path.mu.Unlock()
	}
}

// recordSuccess marks a successful send on a path
func (p *MRCPath) recordSuccess() {
	p.mu.Lock()
	p.SuccessCount++
	p.Score = 0.95
	p.mu.Unlock()
}

// recordFailure marks a failed send on a path
func (p *MRCPath) recordFailure() {
	p.mu.Lock()
	p.FailureCount++
	p.Score *= 0.8
	p.mu.Unlock()
}

// Close shuts down the adapter
func (m *MRCAdapter) Close() error {
	close(m.done)
	close(m.inbox)
	return nil
}
