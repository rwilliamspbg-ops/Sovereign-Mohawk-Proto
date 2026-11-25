package main

import (
	"log"
	"strings"
	"sync"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

// processLiveMultiKrumIndices runs the real Multi-Krum aggregator and returns
// the indices of surviving gradients.
func processLiveMultiKrumIndices(batch [][]float64, f int) ([]int, error) {
	_, indices, _, err := internal.MultiKrumAggregate(batch, f, 0)
	return indices, err
}

func processLiveMultiKrum(batch [][]float64, f int) (selected int, filtered int, err error) {
	indices, err := processLiveMultiKrumIndices(batch, f)
	if err != nil {
		return 0, 0, err
	}
	return len(indices), len(batch) - len(indices), nil
}

type liveGradientEntry struct {
	node   string
	task   string
	round  int
	vector []float64
}

// gradientBatchCollector buffers live gradient submissions until a batch is
// full, then emits one Multi-Krum decision with per-batch and per-node metrics.
type gradientBatchCollector struct {
	mu      sync.Mutex
	pending []liveGradientEntry
	size    int
	f       int
}

func newGradientBatchCollector(size, f int) *gradientBatchCollector {
	if size <= 0 {
		size = 2*f + 4
	}
	if size < 1 {
		size = 1
	}
	return &gradientBatchCollector{size: size, f: f}
}

func (c *gradientBatchCollector) add(node, task string, round int, vector []float64) {
	if c == nil || c.f <= 0 {
		return
	}
	c.mu.Lock()
	c.pending = append(c.pending, liveGradientEntry{node: node, task: task, round: round, vector: vector})
	if len(c.pending) < c.size {
		c.mu.Unlock()
		return
	}
	entries := c.pending
	c.pending = nil
	c.mu.Unlock()

	vectors := make([][]float64, len(entries))
	for i, e := range entries {
		vectors[i] = e.vector
	}
	indices, err := processLiveMultiKrumIndices(vectors, c.f)
	selectedSet := make(map[int]bool, len(indices))
	for _, idx := range indices {
		selectedSet[idx] = true
	}
	selectedNodes := make([]string, 0, len(indices))
	filteredNodes := make([]string, 0, len(entries)-len(indices))
	for i, e := range entries {
		metrics.ObserveMultiKrumNodeDecision(e.node, selectedSet[i])
		if selectedSet[i] {
			selectedNodes = append(selectedNodes, sanitizeLogValue(e.node))
		} else {
			filteredNodes = append(filteredNodes, sanitizeLogValue(e.node))
		}
	}
	metrics.ObserveMultiKrumDecision(len(entries), len(indices), len(filteredNodes), err == nil)
	if err != nil {
		log.Printf("multikrum decision: batch=%d f=%d selected=0 filtered=0 result=error err=%v", len(entries), c.f, err)
		return
	}
	log.Printf("multikrum decision: batch=%d f=%d selected=%d filtered=%d selected_nodes=%s filtered_nodes=%s result=success",
		len(entries), c.f, len(indices), len(filteredNodes),
		strings.Join(selectedNodes, ","), strings.Join(filteredNodes, ","))
}

