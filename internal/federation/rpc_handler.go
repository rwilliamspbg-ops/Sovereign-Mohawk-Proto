// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Federation RPC Handler: Childward gradient aggregation

package federation

import (
	"context"
	"fmt"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// RPCHandler manages incoming gradient streams from child tier nodes
type RPCHandler struct {
	config              TierConfig
	listener            net.Listener
	gradientsReceived   int64
	gradientsAggregated int64

	// Child tier management
	childHealthMu sync.RWMutex
	childHealth   map[string]FederationHealth // childNodeID -> health
	childBuffers  map[string][]*GradientMessage
	bufferMu      sync.Mutex
	maxBufferSize int

	// Aggregation
	aggregationChan    chan *GradientMessage
	aggregationTimeout time.Duration
	done               chan struct{}
}

// NewRPCHandler creates a handler for child tier gradient streams
func NewRPCHandler(config TierConfig, listenAddr string) (*RPCHandler, error) {
	// Create listener (will be bound later in Start)
	handler := &RPCHandler{
		config:             config,
		childHealth:        make(map[string]FederationHealth),
		childBuffers:       make(map[string][]*GradientMessage),
		aggregationChan:    make(chan *GradientMessage, 10000),
		aggregationTimeout: 5 * time.Second,
		maxBufferSize:      config.MaxBufferedGradients,
		done:               make(chan struct{}),
	}

	// Initialize child health tracking
	for _, childID := range config.ChildNodeIDs {
		handler.childHealth[childID] = FederationHealth{
			ParentNodeID:    config.TierID,
			LastHealthCheck: time.Now(),
		}
	}

	return handler, nil
}

// receiveGradient processes an incoming gradient from gRPC or other transport
func (h *RPCHandler) receiveGradient(gradient *GradientMessage) error {
	if gradient == nil || len(gradient.GradientData) == 0 {
		return fmt.Errorf("invalid gradient: nil or empty data")
	}

	// Add to aggregation channel (non-blocking with buffer fallback)
	select {
	case h.aggregationChan <- gradient:
		h.recordGradientReceived(gradient.SourceNodeID)
		return nil
	default:
		// Channel is full, buffer the gradient
		h.bufferMu.Lock()
		defer h.bufferMu.Unlock()

		// Check if we're at capacity
		totalBuffered := 0
		for _, buf := range h.childBuffers {
			totalBuffered += len(buf)
		}
		if totalBuffered >= h.maxBufferSize {
			return fmt.Errorf("aggregation buffer full, dropping gradient")
		}

		// Buffer the gradient
		key := fmt.Sprintf("round-%d", gradient.AggregationRound)
		h.childBuffers[key] = append(h.childBuffers[key], gradient)
		h.recordGradientReceived(gradient.SourceNodeID)

		return nil
	}
}

// Start begins listening for incoming gradients from child nodes
func (h *RPCHandler) Start(listenAddr string) error {
	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return fmt.Errorf("failed to listen on %s: %w", listenAddr, err)
	}
	h.listener = listener
	log.Printf("[%s rpc-handler] listening on %s for %d child nodes",
		h.config.TierID, listenAddr, len(h.config.ChildNodeIDs))

	// Accept connections in background
	go h.acceptLoop()
	return nil
}

// acceptLoop handles incoming connections from child nodes
func (h *RPCHandler) acceptLoop() {
	for {
		select {
		case <-h.done:
			return
		default:
		}

		// Accept with timeout
		h.listener.(*net.TCPListener).SetDeadline(time.Now().Add(1 * time.Second))
		conn, err := h.listener.Accept()
		if err != nil {
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				continue // Timeout, loop again
			}
			log.Printf("ERROR: accept failed: %v", err)
			continue
		}

		// Handle connection in goroutine
		go h.handleConnection(conn)
	}
}

// handleConnection processes incoming gradients from a single child node
func (h *RPCHandler) handleConnection(conn net.Conn) {
	defer conn.Close()

	// TODO: Implement actual gRPC stream handling
	// For now, simulate receiving gradients
	remoteAddr := conn.RemoteAddr().String()
	log.Printf("[%s rpc-handler] accepted connection from %s", h.config.TierID, remoteAddr)

	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-h.done:
			return
		case <-ticker.C:
			// Simulate receiving gradient from stream
			gradient := &GradientMessage{
				GradientID:       fmt.Sprintf("grad-%d", atomic.AddInt64(&h.gradientsReceived, 1)),
				SourceNodeID:     remoteAddr,
				AggregationRound: 1,
				DimensionCount:   1000,
				GradientData:     make([]float64, 1000),
				Timestamp:        time.Now(),
			}
			// Calculate norm
			for i := range gradient.GradientData {
				gradient.GradientData[i] = float64(i)
				gradient.Norm += gradient.GradientData[i] * gradient.GradientData[i]
			}
			gradient.Norm = float64(int(gradient.Norm) % 100)

			// Add to aggregation channel (non-blocking)
			select {
			case h.aggregationChan <- gradient:
				h.recordGradientReceived(remoteAddr)
			default:
				log.Printf("WARN: aggregation channel full, dropping gradient from %s", remoteAddr)
			}
		}
	}
}

// recordGradientReceived updates child health metrics
func (h *RPCHandler) recordGradientReceived(childNodeID string) {
	h.childHealthMu.Lock()
	defer h.childHealthMu.Unlock()

	health := h.childHealth[childNodeID]
	health.GradientsReceived++
	health.LastHealthCheck = time.Now()
	h.childHealth[childNodeID] = health

	atomic.AddInt64(&h.gradientsReceived, 1)
}

// AggregateLoop processes child gradients and matches with parent requests
func (h *RPCHandler) AggregateLoop(ctx context.Context) {
	log.Printf("[%s rpc-handler] aggregate loop started", h.config.TierID)

	ticker := time.NewTicker(h.aggregationTimeout)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Printf("[%s rpc-handler] context cancelled, shutting down", h.config.TierID)
			return

		case <-h.done:
			log.Printf("[%s rpc-handler] shutdown requested", h.config.TierID)
			return

		case gradient := <-h.aggregationChan:
			h.bufferGradient(gradient)

		case <-ticker.C:
			h.flushPendingAggregations(ctx)
		}
	}
}

// bufferGradient buffers an incoming gradient for aggregation
func (h *RPCHandler) bufferGradient(gradient *GradientMessage) {
	h.bufferMu.Lock()
	defer h.bufferMu.Unlock()

	key := fmt.Sprintf("round-%d", gradient.AggregationRound)
	h.childBuffers[key] = append(h.childBuffers[key], gradient)

	// Check if we've exceeded buffer limits
	totalBuffered := 0
	for _, buf := range h.childBuffers {
		totalBuffered += len(buf)
	}
	if totalBuffered > h.maxBufferSize {
		log.Printf("WARN: buffer overflow, dropping oldest gradients")
		// Drop oldest round
		for rk := range h.childBuffers {
			delete(h.childBuffers, rk)
			break
		}
	}
}

// flushPendingAggregations collects child gradients and produces aggregates
func (h *RPCHandler) flushPendingAggregations(ctx context.Context) {
	h.bufferMu.Lock()
	defer h.bufferMu.Unlock()

	for round, gradients := range h.childBuffers {
		if len(gradients) == 0 {
			continue
		}

		// Check if we have minimum quorum
		if len(gradients) < h.config.MinQuorumSize {
			continue
		}

		// TODO: Apply Byzantine multi-Krum filtering
		// For now, simple mean aggregation
		aggregated := h.simpleAggregate(gradients)

		log.Printf(
			"[%s rpc-handler] aggregated %d gradients from children (round=%s) norm=%.4f",
			h.config.TierID,
			len(gradients),
			round,
			aggregated.Norm,
		)

		atomic.AddInt64(&h.gradientsAggregated, 1)
		delete(h.childBuffers, round)
	}
}

// simpleAggregate computes mean of child gradients (placeholder)
func (h *RPCHandler) simpleAggregate(gradients []*GradientMessage) *GradientMessage {
	if len(gradients) == 0 {
		return &GradientMessage{}
	}

	result := &GradientMessage{
		GradientID: fmt.Sprintf("agg-%d", atomic.LoadInt64(&h.gradientsAggregated)),
		Timestamp:  time.Now(),
	}

	dim := len(gradients[0].GradientData)
	result.GradientData = make([]float64, dim)
	result.DimensionCount = dim

	// Compute mean
	for _, g := range gradients {
		for i, val := range g.GradientData {
			result.GradientData[i] += val / float64(len(gradients))
		}
	}

	// Compute norm
	for _, val := range result.GradientData {
		result.Norm += val * val
	}

	return result
}

// GetChildHealth returns health of specific child node
func (h *RPCHandler) GetChildHealth(childNodeID string) (FederationHealth, bool) {
	h.childHealthMu.RLock()
	defer h.childHealthMu.RUnlock()
	health, ok := h.childHealth[childNodeID]
	return health, ok
}

// Stats returns handler statistics
func (h *RPCHandler) Stats() map[string]interface{} {
	h.bufferMu.Lock()
	totalBuffered := 0
	for _, buf := range h.childBuffers {
		totalBuffered += len(buf)
	}
	h.bufferMu.Unlock()

	return map[string]interface{}{
		"tier":                 h.config.TierID,
		"gradients_received":   atomic.LoadInt64(&h.gradientsReceived),
		"gradients_aggregated": atomic.LoadInt64(&h.gradientsAggregated),
		"buffered_gradients":   totalBuffered,
		"child_nodes":          len(h.config.ChildNodeIDs),
		"min_quorum":           h.config.MinQuorumSize,
	}
}

// Close gracefully shuts down RPC handler
func (h *RPCHandler) Close() error {
	close(h.done)
	if h.listener != nil {
		h.listener.Close()
	}
	close(h.aggregationChan)
	log.Printf("[%s rpc-handler] shutting down (received %d, aggregated %d)",
		h.config.TierID, atomic.LoadInt64(&h.gradientsReceived), atomic.LoadInt64(&h.gradientsAggregated))
	return nil
}
