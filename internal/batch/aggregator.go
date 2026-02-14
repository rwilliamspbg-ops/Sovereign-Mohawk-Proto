package batch

import (
	"fmt"
	"math"
)

type Mode int

const (
	ModeHonestOnly Mode = iota
	ModeByzantineMix
)

type Config struct {
	TotalNodes       int
	HonestNodes      int
	MaliciousNodes   int
	RedundancyFactor int
}

type Aggregator struct {
	Config *Config
}

func NewAggregator(cfg *Config) *Aggregator {
	return &Aggregator{Config: cfg}
}

func (a *Aggregator) ProcessRound(mode Mode) error {
	// Theorem 4: Probability of liveness failure
	// success_prob = 1 - exp(-k/2) where k is expected honest successes
	
	// Calculate expected successful honest aggregations (k)
	// In a 10x redundancy setup, regional success p ≈ 0.999
	k := float64(a.Config.HonestNodes) * (1.0 - math.Pow(0.5, float64(a.Config.RedundancyFactor)))
	
	prob := 1.0 - math.Exp(-k/2.0)

	if prob < 0.9999 {
		return fmt.Errorf("liveness check failed: liveness risk: success probability %f below 99.99%% threshold", prob)
	}

	// Theorem 1: Byzantine Safety Check (n > 2f)
	if a.Config.TotalNodes <= 2*a.Config.MaliciousNodes {
		return fmt.Errorf("Byzantine safety violation: n <= 2f")
	}

	return nil
}
