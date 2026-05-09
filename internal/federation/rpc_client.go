// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Federation RPC Client: Parentward gradient forwarding

package federation

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// RPCClient manages gradient forwarding to parent tier nodes
type RPCClient struct {
	config             TierConfig
	parentAddr         string // "host:port" of parent tier aggregator
	health             FederationHealth
	healthMu           sync.RWMutex
	gradientsForwarded int64
	nextRetryTime      time.Time
	retryBackoff       time.Duration // Exponential backoff on failures
}

// NewRPCClient creates a client for parent tier communication
func NewRPCClient(config TierConfig, parentAddr string) *RPCClient {
	return &RPCClient{
		config:       config,
		parentAddr:   parentAddr,
		retryBackoff: 500 * time.Millisecond,
		health: FederationHealth{
			ParentNodeID:    config.ParentTierNodeID,
			LastHealthCheck: time.Now(),
		},
	}
}

// ForwardGradient sends a single gradient to parent tier
func (c *RPCClient) ForwardGradient(ctx context.Context, gradient *GradientMessage) error {
	// Check if we're in backoff
	if time.Now().Before(c.nextRetryTime) {
		return fmt.Errorf("in retry backoff, try again after %v", c.nextRetryTime.Sub(time.Now()))
	}

	// Validate message integrity
	if len(gradient.GradientData) == 0 {
		return fmt.Errorf("empty gradient data in message")
	}

	// Record routing breadcrumb
	gradient.PathHops = append(gradient.PathHops, c.config.TierID)

	// TODO: Implement actual gRPC client call
	// For now, simulate the RPC
	startTime := time.Now()
	err := c.simulateGRPCForward(ctx, gradient)
	latencyMs := float64(time.Since(startTime).Milliseconds())

	if err != nil {
		c.recordFailure(latencyMs)
		// Exponential backoff: 500ms, 1s, 2s, 4s, max 30s
		c.retryBackoff = time.Duration(float64(c.retryBackoff) * 1.5)
		if c.retryBackoff > 30*time.Second {
			c.retryBackoff = 30 * time.Second
		}
		c.nextRetryTime = time.Now().Add(c.retryBackoff)
		return fmt.Errorf("forward failed: %w", err)
	}

	c.recordSuccess(latencyMs)
	c.retryBackoff = 500 * time.Millisecond // Reset on success
	return nil
}

// ForwardBatch forwards multiple gradients to parent tier (more efficient)
func (c *RPCClient) ForwardBatch(ctx context.Context, gradients []*GradientMessage) (accepted int, err error) {
	if len(gradients) == 0 {
		return 0, nil
	}

	// Prepare batch message
	for _, g := range gradients {
		g.PathHops = append(g.PathHops, c.config.TierID)
	}

	startTime := time.Now()
	accepted, err = c.simulateGRPCBatch(ctx, gradients)
	latencyMs := float64(time.Since(startTime).Milliseconds())

	if err != nil {
		c.recordFailure(latencyMs)
		return 0, fmt.Errorf("batch forward failed: %w", err)
	}

	c.recordSuccess(latencyMs)
	return accepted, nil
}

// Health returns current parent tier link status
func (c *RPCClient) Health() FederationHealth {
	c.healthMu.RLock()
	defer c.healthMu.RUnlock()
	return c.health
}

// recordSuccess updates health metrics on successful forward
func (c *RPCClient) recordSuccess(latencyMs float64) {
	c.healthMu.Lock()
	defer c.healthMu.Unlock()

	c.gradientsForwarded++
	c.health.GradientsForwarded++
	c.health.LatencyMs = latencyMs
	c.health.LastHealthCheck = time.Now()

	// Exponential moving average for packet loss
	c.health.PacketLoss = c.health.PacketLoss*0.95 + 0.0
}

// recordFailure updates health metrics on failed forward
func (c *RPCClient) recordFailure(latencyMs float64) {
	c.healthMu.Lock()
	defer c.healthMu.Unlock()

	c.health.LatencyMs = latencyMs
	c.health.LastHealthCheck = time.Now()

	// Exponential moving average for packet loss
	c.health.PacketLoss = c.health.PacketLoss*0.95 + 0.05
}

// simulateGRPCForward simulates gRPC call (placeholder for actual implementation)
func (c *RPCClient) simulateGRPCForward(ctx context.Context, gradient *GradientMessage) error {
	// Simulate 50-200ms RPC latency
	latency := time.Duration(50+int(time.Now().UnixNano()%150)) * time.Millisecond
	select {
	case <-time.After(latency):
		// 99% success rate simulation
		if (int(c.gradientsForwarded) % 100) > 0 {
			return nil
		}
		return fmt.Errorf("simulated RPC timeout")
	case <-ctx.Done():
		return ctx.Err()
	}
}

// simulateGRPCBatch simulates batched gRPC call (placeholder for actual implementation)
func (c *RPCClient) simulateGRPCBatch(ctx context.Context, gradients []*GradientMessage) (int, error) {
	// Simulate batch RPC (scales better than individual)
	latency := time.Duration(50+int(time.Now().UnixNano()%100)) * time.Millisecond
	select {
	case <-time.After(latency):
		// Batch success rate is higher (99.5%)
		accepted := len(gradients)
		if (int(c.gradientsForwarded) % 200) < 1 {
			accepted = len(gradients) / 2 // Partial failure
		}
		if accepted == 0 {
			return 0, fmt.Errorf("simulated batch RPC timeout")
		}
		return accepted, nil
	case <-ctx.Done():
		return 0, ctx.Err()
	}
}

// Close gracefully shuts down RPC client
func (c *RPCClient) Close() error {
	// Flush any pending forwards to parent
	log.Printf("[%s rpc-client] shutting down (forwarded %d gradients)",
		c.config.TierID, c.gradientsForwarded)
	return nil
}
