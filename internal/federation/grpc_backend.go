// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Client-side transport backend for federation: connects to a parent tier's
// RPCHandler listener and forwards gradients using the binary wire protocol
// defined in wire.go.

package federation

import (
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// GRPCClientBackend manages outbound gRPC connections to parent tier
type GRPCClientBackend struct {
	mu                 sync.RWMutex
	config             TierConfig
	parentAddr         string
	conn               net.Conn
	gradientsForwarded int64
	bytesForwarded     int64
	lastError          error
	lastErrorTime      time.Time
}

// NewGRPCClientBackend creates an outbound gRPC client connection
func NewGRPCClientBackend(config TierConfig, parentAddr string) *GRPCClientBackend {
	return &GRPCClientBackend{
		config:     config,
		parentAddr: parentAddr,
	}
}

// Connect establishes connection to parent tier
func (g *GRPCClientBackend) Connect(ctx context.Context) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.conn != nil {
		return nil // Already connected
	}

	dialer := net.Dialer{Timeout: 10 * time.Second}
	conn, err := dialer.DialContext(ctx, "tcp", g.parentAddr)
	if err != nil {
		g.lastError = err
		g.lastErrorTime = time.Now()
		return fmt.Errorf("gRPC dial failed to %s: %w", g.parentAddr, err)
	}

	g.conn = conn
	log.Printf("[grpc-client] connected to %s", g.parentAddr)
	return nil
}

// SendGradient forwards a single gradient and waits for the peer's ACK.
func (g *GRPCClientBackend) SendGradient(ctx context.Context, gradient *GradientMessage) error {
	g.mu.RLock()
	conn := g.conn
	g.mu.RUnlock()

	if conn == nil {
		if err := g.Connect(ctx); err != nil {
			return err
		}
		g.mu.RLock()
		conn = g.conn
		g.mu.RUnlock()
	}

	payload := encodeGradient(gradient)

	writeDeadline := time.Now().Add(30 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(writeDeadline) {
		writeDeadline = deadline
	}
	_ = conn.SetWriteDeadline(writeDeadline)

	if err := writeFrame(conn, msgTypeGradient, payload); err != nil {
		g.recordError(err)
		g.resetConnection()
		return fmt.Errorf("gRPC send failed: %w", err)
	}

	readDeadline := time.Now().Add(30 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(readDeadline) {
		readDeadline = deadline
	}
	_ = conn.SetReadDeadline(readDeadline)

	ack := make([]byte, 1)
	if _, err := io.ReadFull(conn, ack); err != nil {
		g.recordError(err)
		g.resetConnection()
		return fmt.Errorf("gRPC ack read failed: %w", err)
	}
	if ack[0] != ackOK {
		return fmt.Errorf("gRPC gradient rejected by peer")
	}

	atomic.AddInt64(&g.bytesForwarded, int64(len(payload)+5))
	atomic.AddInt64(&g.gradientsForwarded, 1)

	return nil
}

// SendBatch forwards multiple gradients in one frame and waits for the
// peer's batch ACK (which reports how many it actually accepted).
func (g *GRPCClientBackend) SendBatch(ctx context.Context, gradients []*GradientMessage) (int, error) {
	if len(gradients) == 0 {
		return 0, nil
	}
	if len(gradients) > maxBatchCount {
		return 0, fmt.Errorf("batch too large: %d gradients (max %d)", len(gradients), maxBatchCount)
	}

	g.mu.RLock()
	conn := g.conn
	g.mu.RUnlock()

	if conn == nil {
		if err := g.Connect(ctx); err != nil {
			return 0, err
		}
		g.mu.RLock()
		conn = g.conn
		g.mu.RUnlock()
	}

	body := new(bytes.Buffer)
	writeUint32(body, uint32(len(gradients)))
	for _, grad := range gradients {
		payload := encodeGradient(grad)
		writeUint32(body, uint32(len(payload)))
		body.Write(payload)
	}

	writeDeadline := time.Now().Add(60 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(writeDeadline) {
		writeDeadline = deadline
	}
	_ = conn.SetWriteDeadline(writeDeadline)

	if err := writeFrame(conn, msgTypeBatch, body.Bytes()); err != nil {
		g.recordError(err)
		g.resetConnection()
		return 0, fmt.Errorf("gRPC batch send failed: %w", err)
	}

	readDeadline := time.Now().Add(60 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(readDeadline) {
		readDeadline = deadline
	}
	_ = conn.SetReadDeadline(readDeadline)

	respHeader := make([]byte, 5)
	if _, err := io.ReadFull(conn, respHeader); err != nil {
		g.recordError(err)
		g.resetConnection()
		return 0, fmt.Errorf("gRPC batch ack read failed: %w", err)
	}
	if respHeader[0] != ackOK {
		return 0, fmt.Errorf("gRPC batch rejected by peer")
	}
	accepted := int(binary.BigEndian.Uint32(respHeader[1:]))

	atomic.AddInt64(&g.bytesForwarded, int64(body.Len()+5))
	atomic.AddInt64(&g.gradientsForwarded, int64(accepted))

	return accepted, nil
}

// Health checks parent tier connection
func (g *GRPCClientBackend) Health(ctx context.Context) error {
	g.mu.RLock()
	conn := g.conn
	g.mu.RUnlock()

	if conn == nil {
		return fmt.Errorf("not connected")
	}

	writeDeadline := time.Now().Add(10 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(writeDeadline) {
		writeDeadline = deadline
	}
	_ = conn.SetWriteDeadline(writeDeadline)

	if _, err := conn.Write([]byte{msgTypeHealthCheck}); err != nil {
		g.recordError(err)
		g.resetConnection()
		return err
	}

	readDeadline := time.Now().Add(10 * time.Second)
	if deadline, ok := ctx.Deadline(); ok && deadline.Before(readDeadline) {
		readDeadline = deadline
	}
	_ = conn.SetReadDeadline(readDeadline)

	respBuffer := make([]byte, 2)
	if _, err := io.ReadFull(conn, respBuffer); err != nil {
		g.recordError(err)
		g.resetConnection()
		return err
	}

	if respBuffer[0] != msgTypeHealthReply || respBuffer[1] != 1 {
		return fmt.Errorf("parent tier not healthy")
	}

	return nil
}

// recordError records connection errors
func (g *GRPCClientBackend) recordError(err error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.lastError = err
	g.lastErrorTime = time.Now()
}

// resetConnection closes and clears the connection
func (g *GRPCClientBackend) resetConnection() {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.conn != nil {
		g.conn.Close()
		g.conn = nil
	}
}

// Close closes the gRPC client connection
func (g *GRPCClientBackend) Close() error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.conn != nil {
		return g.conn.Close()
	}
	return nil
}

// Stats returns transport statistics
func (g *GRPCClientBackend) Stats() map[string]interface{} {
	g.mu.RLock()
	defer g.mu.RUnlock()

	return map[string]interface{}{
		"gradients_forwarded": atomic.LoadInt64(&g.gradientsForwarded),
		"bytes_forwarded":     atomic.LoadInt64(&g.bytesForwarded),
		"connected":           g.conn != nil,
		"last_error":          g.lastError,
		"last_error_time":     g.lastErrorTime,
	}
}
