package federation

import (
	"context"
	"testing"
)

func TestAggregationCallbackReceivesForwardableUpdate(t *testing.T) {
	config := TierConfig{
		TierID:               "regional-callback-test",
		Level:                TierRegional,
		MinQuorumSize:        2,
		ByzantineToleranceFrac: 0.33,
		MaxBufferedGradients: 100,
	}
	handler, err := NewRPCHandler(config, "")
	if err != nil {
		t.Fatalf("new handler: %v", err)
	}

	var forwarded *GradientMessage
	handler.SetAggregationCallback(func(aggregate *GradientMessage) {
		forwarded = aggregate
	})

	handler.bufferGradient(&GradientMessage{
		GradientID: "g1", SourceNodeID: "child-1", AggregationRound: 7,
		DimensionCount: 2, GradientData: []float64{1, 2},
	})
	handler.bufferGradient(&GradientMessage{
		GradientID: "g2", SourceNodeID: "child-2", AggregationRound: 7,
		DimensionCount: 2, GradientData: []float64{3, 4},
	})
	handler.flushPendingAggregations(context.Background())

	if forwarded == nil {
		t.Fatal("aggregation callback was not invoked")
	}
	if len(forwarded.GradientData) != 2 {
		t.Fatalf("forwarded gradient dimension = %d, want 2", len(forwarded.GradientData))
	}
}
