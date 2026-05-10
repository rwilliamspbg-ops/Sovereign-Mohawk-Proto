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
	grpcBackend        *GRPCClientBackend
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
		grpcBackend: NewGRPCClientBackend(config, parentAddr),
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

	// Use actual gRPC backend
	startTime := time.Now()

	// Ensure connection is established
	if err := c.grpcBackend.Connect(ctx); err != nil {
		c.recordFailure(float64(time.Since(startTime).Milliseconds()))
		c.applyBackoff()
		return fmt.Errorf("gRPC connect failed: %w", err)
	}

	// Send gradient via gRPC
	err := c.grpcBackend.SendGradient(ctx, gradient)
	latencyMs := float64(time.Since(startTime).Milliseconds())

	if err != nil {
		c.recordFailure(latencyMs)
		c.applyBackoff()
		return fmt.Errorf("gRPC forward failed: %w", err)
	}

	c.recordSuccess(latencyMs)
	c.retryBackoff = 500 * time.Millisecond // Reset on success
	return nil
}

// applyBackoff applies exponential backoff on failure
func (c *RPCClient) applyBackoff() {
	c.retryBackoff = time.Duration(float64(c.retryBackoff) * 1.5)
	if c.retryBackoff > 30*time.Second {
		c.retryBackoff = 30 * time.Second
	}
	c.nextRetryTime = time.Now().Add(c.retryBackoff)
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

	// Ensure connection is established
	if err := c.grpcBackend.Connect(ctx); err != nil {
		latencyMs := float64(time.Since(startTime).Milliseconds())
		c.recordFailure(latencyMs)
		c.applyBackoff()
		return 0, fmt.Errorf("gRPC connect failed: %w", err)
	}

	// Send batch via gRPC
	accepted, err = c.grpcBackend.SendBatch(ctx, gradients)
	latencyMs := float64(time.Since(startTime).Milliseconds())

	if err != nil {
		c.recordFailure(latencyMs)
		c.applyBackoff()
		return 0, fmt.Errorf("gRPC batch forward failed: %w", err)
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
	// Deprecated: Use actual gRPC backend instead
	return fmt.Errorf("simulation deprecated, use actual gRPC backend")
}

// simulateGRPCBatch simulates batched gRPC call (placeholder for actual implementation)
func (c *RPCClient) simulateGRPCBatch(ctx context.Context, gradients []*GradientMessage) (int, error) {
	// Deprecated: Use actual gRPC backend instead
	return 0, fmt.Errorf("simulation deprecated, use actual gRPC backend")
}

// Close gracefully shuts down RPC client and gRPC connection
func (c *RPCClient) Close() error {
	log.Printf("[%s rpc-client] shutting down (forwarded %d gradients)",
		c.config.TierID, c.gradientsForwarded)

	if c.grpcBackend != nil {
		return c.grpcBackend.Close()
	}
	return nil
}
