// Copyright 2026 Ryan Williams / Sovereign Mohawk Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"log"
	"sync"
)

// RegionalAggregator manages the collection of gradients for a specific shard.
// It is designed to handle high-concurrency updates in a federated learning environment.
type RegionalAggregator struct {
	ShardID string
	mu      sync.Mutex
	results [][]byte
}

// NewRegionalAggregator initializes a new shard with pre-allocated capacity 
// to optimize memory management for large-scale node deployments.
func NewRegionalAggregator(id string) *RegionalAggregator {
	return &RegionalAggregator{
		ShardID: id,
		results: make([][]byte, 0, 1000),
	}
}

// PushResult safely appends a node's gradient to the regional shard.
func (ra *RegionalAggregator) PushResult(data []byte) {
	ra.mu.Lock()
	defer ra.mu.Unlock()
	ra.results = append(ra.results, data)
	log.Printf("Shard %s: Successfully collected result %d", ra.ShardID, len(ra.results))
}
