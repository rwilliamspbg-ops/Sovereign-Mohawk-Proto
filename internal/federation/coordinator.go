// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Federation Coordinator: Multi-tier orchestration

package federation

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// Coordinator orchestrates multi-tier federation across regional, continental, and global tiers
type Coordinator struct {
	config    TierConfig
	rpcServer *RPCHandler
	rpcClient *RPCClient

	// Statistics
	statsmu           sync.RWMutex
	totalRounds       uint64
	lastRoundTimeMs   float64
	participationRate float64
}

// NewCoordinator creates a federation coordinator for a specific tier
func NewCoordinator(config TierConfig, serverAddr string, parentAddr string) (*Coordinator, error) {
	handler, err := NewRPCHandler(config, serverAddr)
	if err != nil {
		return nil, fmt.Errorf("failed to create RPC handler: %w", err)
	}

	var client *RPCClient
	if parentAddr != "" {
		client = NewRPCClient(config, parentAddr)
	}

	return &Coordinator{
		config:    config,
		rpcServer: handler,
		rpcClient: client,
	}, nil
}

// Start begins listening for child tier connections
func (c *Coordinator) Start(ctx context.Context, listenAddr string) error {
	if err := c.rpcServer.Start(listenAddr); err != nil {
		return err
	}

	// Launch aggregation loop
	go c.rpcServer.AggregateLoop(ctx)

	// Launch health checker
	if c.rpcClient != nil {
		go c.healthCheckLoop(ctx)
	}

	log.Printf("[%s coordinator] started (tier=%s, children=%d, parent=%s)",
		c.config.TierID, tierLevelName(c.config.Level), len(c.config.ChildNodeIDs), c.config.ParentTierNodeID)

	return nil
}

// healthCheckLoop periodically checks health of parent tier connection
func (c *Coordinator) healthCheckLoop(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if c.rpcClient != nil {
				health := c.rpcClient.Health()
				if health.PacketLoss > 0.1 {
					log.Printf("WARN: [%s] parent link degraded: loss=%.1f%% latency=%.1fms",
						c.config.TierID, health.PacketLoss*100, health.LatencyMs)
				}
			}
		}
	}
}

// ForwardGradient forwards a gradient to parent tier (root nodes do final aggregation)
func (c *Coordinator) ForwardGradient(ctx context.Context, gradient *GradientMessage) error {
	if c.rpcClient == nil {
		// This is root tier, don't forward
		return nil
	}

	return c.rpcClient.ForwardGradient(ctx, gradient)
}

// ForwardBatch efficiently forwards multiple gradients to parent tier
func (c *Coordinator) ForwardBatch(ctx context.Context, gradients []*GradientMessage) (int, error) {
	if c.rpcClient == nil {
		// This is root tier, don't forward
		return len(gradients), nil
	}

	return c.rpcClient.ForwardBatch(ctx, gradients)
}

// Stats returns comprehensive federation statistics
func (c *Coordinator) Stats() map[string]interface{} {
	c.statsmu.RLock()
	defer c.statsmu.RUnlock()

	serverStats := c.rpcServer.Stats()

	result := map[string]interface{}{
		"tier":               c.config.TierID,
		"tier_level":         tierLevelName(c.config.Level),
		"total_rounds":       c.totalRounds,
		"last_round_time_ms": c.lastRoundTimeMs,
		"participation_rate": c.participationRate,
	}

	// Merge server stats
	for k, v := range serverStats {
		result[k] = v
	}

	// Add client stats if not root
	if c.rpcClient != nil {
		health := c.rpcClient.Health()
		result["parent_latency_ms"] = health.LatencyMs
		result["parent_packet_loss"] = health.PacketLoss
	}

	return result
}

// Close gracefully shuts down coordinator
func (c *Coordinator) Close() error {
	if c.rpcServer != nil {
		c.rpcServer.Close()
	}
	if c.rpcClient != nil {
		c.rpcClient.Close()
	}
	log.Printf("[%s coordinator] shutdown complete", c.config.TierID)
	return nil
}

// tierLevelName converts tier level to string
func tierLevelName(level TierLevel) string {
	switch level {
	case TierRegional:
		return "regional"
	case TierContinental:
		return "continental"
	case TierGlobal:
		return "global"
	default:
		return "unknown"
	}
}
