// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Federation Protocol: Multi-tier gradient aggregation API

package federation

import (
"time"
)

// TierLevel defines the hierarchical tier in federation
type TierLevel int

const (
TierRegional TierLevel = iota + 1
TierContinental
TierGlobal
)

// GradientMessage represents a gradient tensor for cross-tier forwarding
type GradientMessage struct {
// Identity
GradientID        string
SourceNodeID      string
SourceTierNodeID  string // Tier-level node ID
AggregationRound  uint64

// Gradient data
DimensionCount int
GradientData   []float64
Norm           float64
Timestamp      time.Time

// Provenance
PathHops []string // Breadcrumb trail of tier nodes
Proof    []byte   // Byzantine resilience proof
}

// FederationHealth tracks tier-to-tier link status
type FederationHealth struct {
ParentNodeID    string
LatencyMs       float64
PacketLoss      float64 // 0.0 - 1.0
GradientsForwarded int64
GradientsReceived  int64
LastHealthCheck    time.Time
}

// TierConfig describes a tier in the federation hierarchy
type TierConfig struct {
TierID                 string      // "regional-1", "continental-1", etc.
Level                  TierLevel   // Regional, Continental, Global
ParentTierNodeID       string      // Parent in hierarchy (empty if root)
ChildNodeIDs           []string    // Direct children
MinQuorumSize          int         // Minimum children for consensus
AggregationTimeoutMs   int         // Max time to wait for children
ByzantineToleranceFrac float64     // Fraud resilience (default 0.33)
MaxBufferedGradients   int         // Circuit breaker
}

// AggregationRequest represents a request from parent tier
type AggregationRequest struct {
RoundID        uint64
ChildNodeID    string
RequestedCount int // How many gradients expected
DeadlineMs     int // Milliseconds until timeout
}

// AggregationResponse represents aggregated gradients sent to parent
type AggregationResponse struct {
RoundID           uint64
TierNodeID        string
AggregatedCount   int
SkippedCount      int   // Byzantine filtered
GradientResult    []float64
GradientNorm      float64
AggregationTimeMs int64
}
