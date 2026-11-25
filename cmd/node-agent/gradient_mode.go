package main

import (
	"fmt"
	"hash/fnv"
)

// generateGradientVector produces a deterministic synthetic gradient vector.
// "zero" preserves the legacy all-zero behaviour, "seeded" produces bounded
// per-node/per-round values so Multi-Krum has meaningful distances, and
// "byzantine" adds a single large poisoned coordinate for adversarial tests.
func generateGradientVector(nodeID string, round int, mode string) []float64 {
	vector := make([]float64, 128)
	if mode == "" || mode == "zero" {
		return vector
	}

	h := fnv.New64a()
	_, _ = fmt.Fprintf(h, "%s:%d", nodeID, round)
	state := h.Sum64()
	for i := range vector {
		state = state*6364136223846793005 + 1442695040888963407
		// Map the high bits into [-1, 1).
		vector[i] = float64(int64(state>>33)%2000000) / 1000000.0
	}
	if mode == "byzantine" {
		vector[0] = 1000000.0
	}
	return vector
}
