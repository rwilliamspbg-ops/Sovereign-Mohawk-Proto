// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Per-tier differential privacy epsilon tracking for federated learning

package federation

import (
	"context"
	"fmt"
	"log"
	"math"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// DPTierTracker tracks differential privacy epsilon accounting per aggregation tier
type DPTierTracker struct {
	mu sync.RWMutex

	// Per-tier accountants
	accountants map[string]*internal.RDPAccountant // tierNodeID -> accountant

	// Global DP budget
	globalBudget *internal.RDPAccountant

	// Aggregation statistics
	aggregationsPerTier map[string]int64 // tierNodeID -> count
	totalAggregations   int64
	budgetExhausted     bool
}

// NewDPTierTracker creates a DP tracker for multi-tier federation
// maxGlobalEpsilon: global privacy budget (e.g., 2.0)
// delta: privacy failure probability (e.g., 1e-7)
func NewDPTierTracker(maxGlobalEpsilon float64, delta float64) *DPTierTracker {
	return &DPTierTracker{
		accountants:         make(map[string]*internal.RDPAccountant),
		globalBudget:        internal.NewRDPAccountant(maxGlobalEpsilon, delta),
		aggregationsPerTier: make(map[string]int64),
	}
}

// RecordAggregation records DP epsilon spent during an aggregation at a specific tier
// tierNodeID: unique tier node (e.g., "regional-1", "continental-1", "global-1")
// gradientCount: number of gradients aggregated
// samplingRate: subsampling rate (0.0-1.0)
// noiseMagnitude: DP noise added (relative to gradient norm)
func (t *DPTierTracker) RecordAggregation(tierNodeID string, gradientCount int, samplingRate float64, noiseMagnitude float64) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	if t.budgetExhausted {
		return fmt.Errorf("DP budget exhausted for tier %s", tierNodeID)
	}

	// Get or create per-tier accountant
	if _, ok := t.accountants[tierNodeID]; !ok {
		t.accountants[tierNodeID] = internal.NewRDPAccountant(100.0, 1e-7) // Per-tier budget
	}

	tierAccountant := t.accountants[tierNodeID]

	// Calculate RDP epsilon for this aggregation step
	// Using Gaussian DP composition:
	// epsilon ≈ sqrt(2) * sqrt(log(1/delta)) / (noise_magnitude * sqrt(gradient_count * sampling_rate))
	if samplingRate <= 0 || noiseMagnitude <= 0 || gradientCount <= 0 {
		return fmt.Errorf("invalid DP parameters: sampling_rate=%f, noise=%f, count=%d",
			samplingRate, noiseMagnitude, gradientCount)
	}

	epsilon := calculateGaussianEpsilon(samplingRate, noiseMagnitude, float64(gradientCount), 1e-7)

	// Record epsilon in tier-specific accountant
	tierAccountant.RecordStep(epsilon)

	// Record epsilon in global accountant
	t.globalBudget.RecordShardStep(tierNodeID, epsilon)

	// Update statistics
	t.aggregationsPerTier[tierNodeID]++
	t.totalAggregations++

	// Check if global budget is exhausted
	globalEps := t.globalBudget.Rdp2Eps(1.0, 1e-7)
	if globalEps > 100.0 { // Hard limit
		t.budgetExhausted = true
		log.Printf("WARNING: Global DP budget exhausted at tier %s (epsilon=%.4f)", tierNodeID, globalEps)
		return fmt.Errorf("global DP budget exhausted")
	}

	log.Printf("[DP-tracking] Tier=%s, Agg=%d, Tier-Epsilon=%.4f, Global-Epsilon=%.4f",
		tierNodeID, t.aggregationsPerTier[tierNodeID], tierAccountant.Rdp2Eps(1.0, 1e-7), globalEps)

	return nil
}

// GetTierEpsilon returns cumulative epsilon spent by a specific tier
func (t *DPTierTracker) GetTierEpsilon(tierNodeID string) float64 {
	t.mu.RLock()
	defer t.mu.RUnlock()

	if accountant, ok := t.accountants[tierNodeID]; ok {
		return accountant.Rdp2Eps(1.0, 1e-7)
	}
	return 0.0
}

// GetGlobalEpsilon returns cumulative global epsilon
func (t *DPTierTracker) GetGlobalEpsilon() float64 {
	t.mu.RLock()
	defer t.mu.RUnlock()

	return t.globalBudget.Rdp2Eps(1.0, 1e-7)
}

// GetTierStats returns aggregation statistics for a tier
func (t *DPTierTracker) GetTierStats(tierNodeID string) map[string]interface{} {
	t.mu.RLock()
	defer t.mu.RUnlock()

	stats := map[string]interface{}{
		"aggregations": t.aggregationsPerTier[tierNodeID],
		"epsilon":      0.0,
	}

	if accountant, ok := t.accountants[tierNodeID]; ok {
		stats["epsilon"] = accountant.Rdp2Eps(1.0, 1e-7)
	}

	return stats
}

// GetGlobalStats returns overall DP accounting statistics
func (t *DPTierTracker) GetGlobalStats() map[string]interface{} {
	t.mu.RLock()
	defer t.mu.RUnlock()

	tierStats := make(map[string]float64)
	for tierID, accountant := range t.accountants {
		tierStats[tierID] = accountant.Rdp2Eps(1.0, 1e-7)
	}

	return map[string]interface{}{
		"total_aggregations": t.totalAggregations,
		"global_epsilon":     t.globalBudget.Rdp2Eps(1.0, 1e-7),
		"tier_epsilon":       tierStats,
		"budget_exhausted":   t.budgetExhausted,
		"num_tiers":          len(t.accountants),
	}
}

// CoordinatorWithDP wraps Coordinator with per-tier DP tracking
type CoordinatorWithDP struct {
	coordinator *Coordinator
	dpTracker   *DPTierTracker

	tierNodeID     string
	samplingRate   float64
	noiseMagnitude float64
}

// NewCoordinatorWithDP creates a coordinator with DP tracking
func NewCoordinatorWithDP(config TierConfig, serverAddr string, parentAddr string,
	dpTracker *DPTierTracker) (*CoordinatorWithDP, error) {

	coordinator, err := NewCoordinator(config, serverAddr, parentAddr)
	if err != nil {
		return nil, err
	}

	return &CoordinatorWithDP{
		coordinator:    coordinator,
		dpTracker:      dpTracker,
		tierNodeID:     config.TierID,
		samplingRate:   1.0,   // Default: no sampling
		noiseMagnitude: 0.001, // Small noise (high utility)
	}, nil
}

// SetDPParameters configures sampling and noise level for this tier
func (c *CoordinatorWithDP) SetDPParameters(samplingRate, noiseMagnitude float64) {
	if samplingRate > 0 && samplingRate <= 1.0 {
		c.samplingRate = samplingRate
	}
	if noiseMagnitude > 0 {
		c.noiseMagnitude = noiseMagnitude
	}
}

// RecordAggregation records aggregation and updates DP accounting
func (c *CoordinatorWithDP) RecordAggregation(gradientCount int) error {
	if c.dpTracker != nil {
		return c.dpTracker.RecordAggregation(c.tierNodeID, gradientCount, c.samplingRate, c.noiseMagnitude)
	}
	return nil
}

// Start wraps coordinator start with DP context
func (c *CoordinatorWithDP) Start(ctx context.Context, listenAddr string) error {
	return c.coordinator.Start(ctx, listenAddr)
}

// Stop cleanly shuts down coordinator
func (c *CoordinatorWithDP) Stop() error {
	if c.coordinator.rpcClient != nil {
		return c.coordinator.rpcClient.Close()
	}
	return nil
}

// GetDPStats returns current DP accounting statistics
func (c *CoordinatorWithDP) GetDPStats() map[string]interface{} {
	return c.dpTracker.GetGlobalStats()
}

// calculateGaussianEpsilon computes (ε, δ)-DP epsilon for Gaussian mechanism
// Using: epsilon ≈ sqrt(2) * sqrt(log(1/delta)) / (noise_magnitude * sqrt(n * sampling_rate))
// where n is the effective number of gradients
func calculateGaussianEpsilon(samplingRate float64, noiseMagnitude float64, gradientCount float64, delta float64) float64 {
	if noiseMagnitude <= 0 || samplingRate <= 0 || gradientCount <= 0 {
		return 0.0
	}

	// sqrt(log(1/delta))
	sqrtLogInvDelta := 0.0
	if delta > 0 && delta < 1.0 {
		// Use simplified formula: sqrt(log(2/delta))
		sqrtLogInvDelta = math.Sqrt(math.Log(2.0 / delta))
	}

	// Effective count = n * sampling_rate
	effectiveCount := gradientCount * samplingRate

	// epsilon ≈ sqrt(2) * sqrt(log(1/delta)) / (noise_magnitude * sqrt(n * sampling_rate))
	denominator := noiseMagnitude * math.Sqrt(effectiveCount)
	if denominator <= 0 {
		return 0.0
	}

	epsilon := (math.Sqrt(2.0) * sqrtLogInvDelta) / denominator

	return epsilon
}

// MonitorDPBudget periodically checks DP budget status across all tiers
func MonitorDPBudget(ctx context.Context, tracker *DPTierTracker, checkInterval time.Duration) {
	ticker := time.NewTicker(checkInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			stats := tracker.GetGlobalStats()
			globalEpsilon := stats["global_epsilon"].(float64)
			numTiers := stats["num_tiers"].(int)

			log.Printf("[DP-Monitor] Global Epsilon: %.4f, Tiers: %d, Exhausted: %v",
				globalEpsilon, numTiers, stats["budget_exhausted"].(bool))

			// Alert if approaching budget limit
			if globalEpsilon > 1.5 { // 1.5 out of 2.0 default
				log.Printf("WARNING: DP budget approaching limit (%.4f/2.0)", globalEpsilon)
			}
		}
	}
}
