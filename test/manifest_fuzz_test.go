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
		_ = m.ValidateCommunicationComplexity(2, 4)
	})
}
