// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Federation RPC Handler: Childward gradient aggregation

package federation

import (
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
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
	// Active connections tracking for graceful shutdown
	connMu sync.Mutex
	conns  map[net.Conn]struct{}
	connWg sync.WaitGroup
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
		conns:              make(map[net.Conn]struct{}),
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
			select {
			case <-h.done:
				// Listener was closed as part of shutdown; exit quietly
				// instead of busy-looping on "use of closed network
				// connection" until the top-of-loop check catches up.
				return
			default:
			}
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				continue // Timeout, loop again
			}
			log.Printf("ERROR: accept failed: %v", err)
			continue
		}

		// Track and handle connection in goroutine
		h.connWg.Add(1)
		h.addConn(conn)
		go func(c net.Conn) {
			defer h.connWg.Done()
			defer h.removeConn(c)
			h.handleConnection(c)
		}(conn)
	}
}

// addConn registers an active connection
func (h *RPCHandler) addConn(c net.Conn) {
	h.connMu.Lock()
	defer h.connMu.Unlock()
	h.conns[c] = struct{}{}
}

// removeConn unregisters an active connection
func (h *RPCHandler) removeConn(c net.Conn) {
	h.connMu.Lock()
	defer h.connMu.Unlock()
	delete(h.conns, c)
}

// handleConnection processes incoming messages from a single child node
// using the binary wire protocol (wire.go): a 1-byte message type followed
// by a length-prefixed payload for gradient/batch messages.
func (h *RPCHandler) handleConnection(conn net.Conn) {
	defer conn.Close()

	remoteAddr := conn.RemoteAddr().String()
	log.Printf("[%s rpc-handler] accepted connection from %s", h.config.TierID, remoteAddr)

	msgType := make([]byte, 1)
	for {
		select {
		case <-h.done:
			return
		default:
		}

		_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		if _, err := io.ReadFull(conn, msgType); err != nil {
			if err != io.EOF {
				log.Printf("[%s rpc-handler] connection from %s closed: %v", h.config.TierID, remoteAddr, err)
			}
			return
		}

		switch msgType[0] {
		case msgTypeGradient:
			if err := h.handleGradientFrame(conn, remoteAddr); err != nil {
				log.Printf("WARN: [%s rpc-handler] gradient frame from %s: %v", h.config.TierID, remoteAddr, err)
				return
			}
		case msgTypeBatch:
			if err := h.handleBatchFrame(conn, remoteAddr); err != nil {
				log.Printf("WARN: [%s rpc-handler] batch frame from %s: %v", h.config.TierID, remoteAddr, err)
				return
			}
		case msgTypeHealthCheck:
			if err := h.handleHealthCheckFrame(conn); err != nil {
				log.Printf("WARN: [%s rpc-handler] health check from %s: %v", h.config.TierID, remoteAddr, err)
				return
			}
		default:
			log.Printf("WARN: [%s rpc-handler] unknown message type %d from %s", h.config.TierID, msgType[0], remoteAddr)
			return
		}
	}
}

// handleGradientFrame reads, decodes, and buffers a single-gradient frame,
// then acknowledges it to the sender.
func (h *RPCHandler) handleGradientFrame(conn net.Conn, remoteAddr string) error {
	payloadLen, err := readFrameLen(conn)
	if err != nil {
		return fmt.Errorf("read frame length: %w", err)
	}

	gradient, decodeErr := decodeGradient(limitedPayloadReader(conn, payloadLen))
	if decodeErr != nil {
		_, _ = conn.Write([]byte{ackErr})
		return fmt.Errorf("decode gradient: %w", decodeErr)
	}
	if gradient.SourceNodeID == "" {
		gradient.SourceNodeID = remoteAddr
	}

	if err := h.receiveGradient(gradient); err != nil {
		_, _ = conn.Write([]byte{ackErr})
		return fmt.Errorf("receive gradient: %w", err)
	}

	_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	if _, err := conn.Write([]byte{ackOK}); err != nil {
		return fmt.Errorf("write ack: %w", err)
	}
	return nil
}

// handleBatchFrame reads and processes a batch-of-gradients frame,
// acknowledging with the number of gradients actually accepted.
func (h *RPCHandler) handleBatchFrame(conn net.Conn, remoteAddr string) error {
	payloadLen, err := readFrameLen(conn)
	if err != nil {
		return fmt.Errorf("read frame length: %w", err)
	}
	body := limitedPayloadReader(conn, payloadLen)

	count, err := readUint32(body)
	if err != nil {
		h.writeBatchAck(conn, ackErr, 0)
		return fmt.Errorf("read batch count: %w", err)
	}
	if count > maxBatchCount {
		h.writeBatchAck(conn, ackErr, 0)
		return fmt.Errorf("batch count too large: %d", count)
	}

	accepted := 0
	for i := uint32(0); i < count; i++ {
		gradLen, err := readFrameLen(body)
		if err != nil {
			h.writeBatchAck(conn, ackErr, accepted)
			return fmt.Errorf("read batch gradient %d length: %w", i, err)
		}
		gradient, decodeErr := decodeGradient(limitedPayloadReader(body, gradLen))
		if decodeErr != nil {
			log.Printf("WARN: [%s rpc-handler] batch gradient %d from %s decode failed: %v",
				h.config.TierID, i, remoteAddr, decodeErr)
			continue
		}
		if gradient.SourceNodeID == "" {
			gradient.SourceNodeID = remoteAddr
		}
		if err := h.receiveGradient(gradient); err != nil {
			log.Printf("WARN: [%s rpc-handler] batch gradient %d from %s rejected: %v",
				h.config.TierID, i, remoteAddr, err)
			continue
		}
		accepted++
	}

	h.writeBatchAck(conn, ackOK, accepted)
	return nil
}

// writeBatchAck sends the 5-byte batch acknowledgement: [status][acceptedCount].
func (h *RPCHandler) writeBatchAck(conn net.Conn, status byte, accepted int) {
	resp := make([]byte, 5)
	resp[0] = status
	binary.BigEndian.PutUint32(resp[1:], uint32(accepted))
	_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	_, _ = conn.Write(resp)
}

// handleHealthCheckFrame replies to a health-check request from a child node.
func (h *RPCHandler) handleHealthCheckFrame(conn net.Conn) error {
	_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	if _, err := conn.Write([]byte{msgTypeHealthReply, 1}); err != nil {
		return fmt.Errorf("write health reply: %w", err)
	}
	return nil
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

		case gradient, ok := <-h.aggregationChan:
			if !ok {
				log.Printf("[%s rpc-handler] aggregation channel closed, exiting aggregate loop", h.config.TierID)
				return
			}
			if gradient == nil {
				continue
			}
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

		aggregated, method := h.aggregate(gradients)

		log.Printf(
			"[%s rpc-handler] aggregated %d gradients from children (round=%s) method=%s norm=%.4f",
			h.config.TierID,
			len(gradients),
			round,
			method,
			aggregated.Norm,
		)

		atomic.AddInt64(&h.gradientsAggregated, 1)
		delete(h.childBuffers, round)
	}
}

// aggregate combines child gradients using Byzantine-robust Multi-Krum
// selection when there are enough participants; it falls back to a plain
// mean when there are too few updates for Multi-Krum's n > 2f+2 requirement
// (e.g. small test topologies or a tier with very few children).
func (h *RPCHandler) aggregate(gradients []*GradientMessage) (result *GradientMessage, method string) {
	aggregated, err := h.multiKrumAggregate(gradients)
	if err != nil {
		log.Printf("WARN: [%s rpc-handler] multi-krum unavailable (%v), falling back to mean aggregation",
			h.config.TierID, err)
		return h.simpleAggregate(gradients), "mean-fallback"
	}
	return aggregated, "multi-krum"
}

// multiKrumAggregate runs Byzantine-robust Multi-Krum selection over the
// buffered child gradients (internal.MultiKrumAggregate) and returns the
// mean of the selected, presumed-honest subset.
func (h *RPCHandler) multiKrumAggregate(gradients []*GradientMessage) (*GradientMessage, error) {
	n := len(gradients)
	updates := make([][]float64, n)
	for i, g := range gradients {
		updates[i] = g.GradientData
	}

	f := int(h.config.ByzantineToleranceFrac * float64(n))
	for f > 0 && n <= 2*f+2 {
		f--
	}
	if n <= 2*f+2 {
		return nil, fmt.Errorf("not enough updates (n=%d) for multi-krum at byzantine tolerance %.2f",
			n, h.config.ByzantineToleranceFrac)
	}

	mean, selected, _, err := internal.MultiKrumAggregate(updates, f, 0)
	if err != nil {
		return nil, err
	}

	result := &GradientMessage{
		GradientID:     fmt.Sprintf("agg-%d", atomic.LoadInt64(&h.gradientsAggregated)),
		Timestamp:      time.Now(),
		DimensionCount: len(mean),
		GradientData:   mean,
	}
	for _, v := range mean {
		result.Norm += v * v
	}

	log.Printf("[%s rpc-handler] multi-krum selected %d/%d children (f=%d)", h.config.TierID, len(selected), n, f)
	return result, nil
}

// simpleAggregate computes mean of child gradients (fallback when there
// aren't enough updates for Multi-Krum's Byzantine-tolerance guarantee).
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
	// Signal goroutines to stop first, so acceptLoop's post-Accept-error
	// check sees it immediately instead of logging/spinning on "use of
	// closed network connection" until its next top-of-loop check.
	select {
	case <-h.done:
		// already closed
	default:
		close(h.done)
	}

	// Close the listener to unblock any in-flight Accept
	if h.listener != nil {
		_ = h.listener.Close()
	}

	// Close active connections to unblock any Read/Write
	h.connMu.Lock()
	for c := range h.conns {
		_ = c.Close()
	}
	h.connMu.Unlock()

	// Wait for connection handlers to finish
	h.connWg.Wait()

	// Now safe to close aggregation channel
	close(h.aggregationChan)

	log.Printf("[%s rpc-handler] shutting down (received %d, aggregated %d)",
		h.config.TierID, atomic.LoadInt64(&h.gradientsReceived), atomic.LoadInt64(&h.gradientsAggregated))
	return nil
}
