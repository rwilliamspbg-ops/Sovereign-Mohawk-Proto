package transport

import (
	"context"
	"testing"
)

func TestProperty_MRCAdapter_SendChunkRegisteredDest(t *testing.T) {
	for paths := 1; paths <= 8; paths++ {
		adapter := NewMRCAdapter("node", paths)
		adapter.RegisterDestination("dest")
		chunk := GradientChunk{
			ID:      "c",
			NodeID:  "node",
			Index:   0,
			Total:   1,
			Payload: []float32{1, 2, 3},
		}
		if err := adapter.SendChunk(context.Background(), "dest", chunk); err != nil {
			t.Fatalf("paths=%d: SendChunk failed: %v", paths, err)
		}
		health := adapter.Health()
		if len(health) != paths {
			t.Fatalf("paths=%d: health len=%d", paths, len(health))
		}
	}
}