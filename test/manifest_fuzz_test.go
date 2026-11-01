package test

import (
	"encoding/json"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
)

func FuzzManifestUnmarshal(f *testing.F) {
	f.Add([]byte(`{"task_id":"t","node_id":"n","max_mem_pages":10,"epsilon":0.1}`))
	f.Add([]byte(`{}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		var m manifest.Manifest
		if err := json.Unmarshal(data, &m); err != nil {
			return
		}
		b, err := json.Marshal(m)
		if err != nil {
			t.Fatalf("marshal failed: %v", err)
		}
		var m2 manifest.Manifest
		if err := json.Unmarshal(b, &m2); err != nil {
			t.Fatalf("round-trip unmarshal failed: %v", err)
		}
		if m.TaskID != m2.TaskID || m.NodeID != m2.NodeID {
			t.Fatalf("round-trip identity mismatch")
		}
		_ = m.ValidateCommunicationComplexity(2, 4)
	})
}
