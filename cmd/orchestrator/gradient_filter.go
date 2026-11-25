package main

import (
	"log"
	"sync"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

// processLiveMultiKrum runs the real Multi-Krum aggregator over one batch of
// live gradient submissions and reports how many survived the filter.
func processLiveMultiKrum(batch [][]float64, f int) (selected int, filtered int, err error) {
	_, indices, _, err := internal.MultiKrumAggregate(batch, f, 0)
	if err != nil {
		return 0, 0, err
	}
	selected = len(indices)
	return selected, len(batch) - selected, nil
}

// gradientBatchCollector buffers live gradient submissions until a batch is
// full, then emits one Multi-Krum decision with per-batch metrics.
type gradientBatchCollector struct {
	mu      sync.Mutex
	pending [][]float64
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
	c.pending = append(c.pending, vector)
	if len(c.pending) < c.size {
		c.mu.Unlock()
		return
	}
	batch := c.pending
	c.pending = nil
	c.mu.Unlock()

	selected, filtered, err := processLiveMultiKrum(batch, c.f)
	metrics.ObserveMultiKrumDecision(len(batch), selected, filtered, err == nil)
	if err != nil {
		log.Printf("multikrum decision: batch=%d f=%d selected=0 filtered=0 result=error err=%v", len(batch), c.f, err)
		return
	}
	log.Printf("multikrum decision: batch=%d f=%d selected=%d filtered=%d result=success last_node=%s last_task=%s last_round=%d",
		len(batch), c.f, selected, filtered, sanitizeLogValue(node), sanitizeLogValue(task), round)
}
