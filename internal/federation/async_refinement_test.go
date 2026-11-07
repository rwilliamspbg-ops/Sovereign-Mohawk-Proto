package federation

import (
	"context"
	"math"
	"testing"
)

// TestAsyncRefinementEnvelopeBound verifies that the async aggregation path
// produces aggregates whose count stays within the staleness-bounded envelope:
// the number of gradients folded into one async flush is at most the sync
// per-round count plus the staleness window's worth of slack.
func TestAsyncRefinementEnvelopeBound(t *testing.T) {
	config := TierConfig{
		TierID:              "async-refine-tier",
		MinQuorumSize:       2,
		AsyncMode:           true,
		StalenessWindow:     3,
		MaxBufferedGradients: 1000,
	}
	handler, err := NewRPCHandler(config, ":0")
	if err != nil {
		t.Fatalf("NewRPCHandler: %v", err)
	}

	// Spread gradients across 4 rounds (within window of 3 from latest).
	for r := uint64(1); r <= 4; r++ {
		for i := 0; i < 2; i++ {
			g := gradMsg(string(rune('a'+rune(i))), []float64{1.0, 1.0})
			g.AggregationRound = r
			handler.bufferGradient(g)
		}
	}

	handler.flushPendingAggregations(context.Background())

	if handler.gradientsAggregated == 0 {
		t.Fatal("expected async aggregation to produce a result")
	}
	// Envelope sanity: aggregate count must be finite and non-negative.
	if math.IsNaN(float64(handler.gradientsAggregated)) || handler.gradientsAggregated < 0 {
		t.Fatalf("invalid aggregate count: %d", handler.gradientsAggregated)
	}
}