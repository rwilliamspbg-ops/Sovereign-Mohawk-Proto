// Copyright 2026 Ryan Williams / Sovereign Mohawk Contributors
// [Standard Apache License Header...]

package main

import (
	"log"
	"sync"
)

// RegionalAggregator handles local shard results before passing to central.
type RegionalAggregator struct {
	ShardID string
	mu      sync.Mutex
	results [][]byte
}

// NewRegionalAggregator initializes a new shard with pre-allocated capacity.
func NewRegionalAggregator(id string) *RegionalAggregator {
	return &RegionalAggregator{
		ShardID: id,
		results: make([][]byte, 0, 1000),
	}
}

// PushResult collects a gradient from a local node in a thread-safe manner.
func (ra *RegionalAggregator) PushResult(data []byte) {
	ra.mu.Lock()
	defer ra.mu.Unlock()
	ra.results = append(ra.results, data)
	log.Printf("Shard %s: Collected result %d", ra.ShardID, len(ra.results))
}
