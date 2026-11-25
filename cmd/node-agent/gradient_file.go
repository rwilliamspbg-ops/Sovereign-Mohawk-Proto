package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
)

type gradientFilePayload struct {
	NodeID   string    `json:"node_id"`
	Gradient []float64 `json:"gradient"`
}

// parseGradientFile reads a trained gradient vector exported by a trainer.
func parseGradientFile(path string) ([]float64, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read gradient file: %w", err)
	}
	var payload gradientFilePayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil, fmt.Errorf("decode gradient file: %w", err)
	}
	if len(payload.Gradient) == 0 {
		return nil, fmt.Errorf("gradient file contains no gradient")
	}
	for i, value := range payload.Gradient {
		if math.IsNaN(value) || math.IsInf(value, 0) {
			return nil, fmt.Errorf("gradient[%d] is not finite", i)
		}
	}
	return payload.Gradient, nil
}

func gradientNorm(vector []float64) float64 {
	sum := 0.0
	for _, value := range vector {
		sum += value * value
	}
	return math.Sqrt(sum)
}
