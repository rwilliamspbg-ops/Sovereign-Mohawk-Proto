// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// MRC-Compatible Transport Layer for Distributed Federated Learning

package transport

import (
	"context"
	"time"
)

// GradientChunk represents a verified shard of a gradient tensor
// Enables streaming aggregation instead of batch-only processing
type GradientChunk struct {
	ID       string    // Unique chunk ID (nodeID-round-index)
	NodeID   string    // Source node ID
	Index    int       // Position in full tensor (0 to Total-1)
	Total    int       // Total chunks for this tensor
	Payload  []float32 // Actual gradient values
	Hash     []byte    // SHA256 hash for verification
	Proof    []byte    // Cryptographic proof (Ed25519 signature)
	SentTime int64     // Timestamp when sent (nanoseconds)
}

// TransportHealth tracks the health of a virtual path
type TransportHealth struct {
	PathID         string        // Unique path identifier
	Latency        time.Duration // Round-trip latency
	PacketLoss     float64       // Loss rate (0.0-1.0)
	ThroughputMBps float64       // Measured throughput
	LastSeen       time.Time     // Last health update
	IsHealthy      bool          // Current health status
}

// Transport is the core abstraction boundary
// Implementations handle different transport mechanisms:
//   - MRC Adapter (multi-path packet spraying - Phase-0)
//   - TCP (fallback/baseline - future)
//   - QUIC (future, for real-world deployment)
//   - RDMA/RoCE (future, for HPC supercluster mode)
type Transport interface {
	// SendChunk delivers a gradient chunk to destination
	// MRC mode: sprays across multiple paths
	SendChunk(ctx context.Context, dest string, chunk GradientChunk) error

	// Receive returns a channel of chunks from any source
	// Non-blocking; caller should select on this channel
	Receive(ctx context.Context) (<-chan GradientChunk, error)

	// Health returns status of all active paths
	// Used for monitoring and adaptive scheduling
	Health() []TransportHealth

	// Close gracefully shuts down the transport
	Close() error
}

// Config for transport selection and tuning
type Config struct {
	Type            string // "tcp", "mrc", "quic"
	LocalAddr       string // Listen address
	NumPaths        int    // For MRC: concurrent paths (default 4)
	ChunkSizeBytes  int    // Size of each chunk payload
	BufferSize      int    // Receive buffer size
	HealthCheckFreq time.Duration
}

// NewTransport factory function creates appropriate transport type
func NewTransport(cfg Config) (Transport, error) {
	// Phase-0: all use MRC adapter
	if cfg.NumPaths == 0 {
		cfg.NumPaths = 4
	}
	return NewMRCAdapter(cfg.LocalAddr, cfg.NumPaths), nil
}
