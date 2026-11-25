package main

import (
	"context"
	"fmt"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/federation"
)

// forwardGradientToFederation sends the same gradient vector up a federation
// parent link, enabling a real node-agent to feed a regional aggregator.
func forwardGradientToFederation(ctx context.Context, nodeID string, round int, vector []float64, parent string) error {
	config := federation.TierConfig{
		TierID:                 nodeID,
		Level:                  federation.TierRegional,
		ParentTierNodeID:       "global-1",
		ChildNodeIDs:           []string{nodeID},
		MinQuorumSize:          1,
		MaxBufferedGradients:   1000,
		ByzantineToleranceFrac: 0.33,
	}
	client := federation.NewRPCClient(config, parent)
	defer client.Close()

	message := &federation.GradientMessage{
		GradientID:       fmt.Sprintf("%s-r%d", nodeID, round),
		SourceNodeID:     nodeID,
		SourceTierNodeID: nodeID,
		AggregationRound: uint64(round),
		DimensionCount:   len(vector),
		GradientData:     vector,
		Norm:             gradientNorm(vector),
		Timestamp:        time.Now().UTC(),
	}
	return client.ForwardGradient(ctx, message)
}
