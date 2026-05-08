// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Topology: Manages cluster membership and aggregation tree

package cluster

import (
	"fmt"
	"sync"
	"time"
)

type NodeRole int

const (
	EdgeNode NodeRole = iota
	RegionalAggregator
	GlobalCoordinator
)

// NodeMetadata tracks node health and assignment
type NodeMetadata struct {
	ID             string
	Role           NodeRole
	LastHeartbeat  time.Time
	Reputation     float64 // 0.0-1.0 (Byzantine scoring)
	Latency        time.Duration
	AssignedRegion string
	AssignedTier   string
	IsHealthy      bool
}

// Topology manages cluster membership and aggregation trees
type Topology struct {
	nodes      map[string]*NodeMetadata
	edges      map[string][]string // node -> aggregators (redundant paths)
	mu         sync.RWMutex
	lastUpdate time.Time
}

func NewTopology() *Topology {
	return &Topology{
		nodes:      make(map[string]*NodeMetadata),
		edges:      make(map[string][]string),
		lastUpdate: time.Now(),
	}
}

// RegisterNode adds a node to the cluster
func (t *Topology) RegisterNode(id string, role NodeRole) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.nodes[id] = &NodeMetadata{
		ID:            id,
		Role:          role,
		LastHeartbeat: time.Now(),
		Reputation:    1.0,
		IsHealthy:     true,
	}

	return nil
}

// AssignAggregator maps edge node to aggregators (with 3-way redundancy)
func (t *Topology) AssignAggregator(edgeNodeID string, aggregators []string) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	// Assign 2-3 aggregators for path diversity
	numPaths := 3
	if len(aggregators) < numPaths {
		numPaths = len(aggregators)
	}

	t.edges[edgeNodeID] = aggregators[:numPaths]
	return nil
}

// GetAssignedAggregators returns primary + backup aggregators
func (t *Topology) GetAssignedAggregators(edgeNodeID string) ([]string, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()

	aggs, exists := t.edges[edgeNodeID]
	if !exists {
		return nil, fmt.Errorf("node %s not assigned", edgeNodeID)
	}

	return aggs, nil
}

// UpdateReputation adjusts Byzantine scoring
func (t *Topology) UpdateReputation(nodeID string, delta float64) {
	t.mu.Lock()
	defer t.mu.Unlock()

	if node, exists := t.nodes[nodeID]; exists {
		node.Reputation += delta
		if node.Reputation < 0 {
			node.Reputation = 0
		}
		if node.Reputation > 1.0 {
			node.Reputation = 1.0
		}
	}
}

// HealthCheck identifies nodes to exclude
func (t *Topology) HealthCheck() []string {
	t.mu.Lock()
	defer t.mu.Unlock()

	unhealthy := make([]string, 0)
	now := time.Now()

	for id, node := range t.nodes {
		// Heartbeat timeout
		if now.Sub(node.LastHeartbeat) > 30*time.Second {
			node.IsHealthy = false
			unhealthy = append(unhealthy, id)
			continue
		}

		// Low reputation = Byzantine
		if node.Reputation < 0.3 {
			node.IsHealthy = false
			unhealthy = append(unhealthy, id)
			continue
		}

		node.IsHealthy = true
	}

	return unhealthy
}

// GetNodeCount returns total nodes
func (t *Topology) GetNodeCount(role NodeRole) int {
	t.mu.RLock()
	defer t.mu.RUnlock()

	count := 0
	for _, node := range t.nodes {
		if node.Role == role {
			count++
		}
	}
	return count
}

// GetHealthyNodes returns nodes that passed health checks
func (t *Topology) GetHealthyNodes() int {
	t.mu.RLock()
	defer t.mu.RUnlock()

	count := 0
	for _, node := range t.nodes {
		if node.IsHealthy {
			count++
		}
	}
	return count
}
