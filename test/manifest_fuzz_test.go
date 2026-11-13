package test

import (
	"crypto/ed25519"
	"crypto/x509"
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

// FuzzManifestSignature asserts the signature round-trip: a correctly signed
// manifest verifies, and any tampering with a signed field invalidates it.
func FuzzManifestSignature(f *testing.F) {
	f.Add([]byte(`{"task_id":"t","node_id":"n","max_mem_pages":10,"epsilon":0.1}`))
	f.Add([]byte(`{}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		var m manifest.Manifest
		if err := json.Unmarshal(data, &m); err != nil {
			return
		}
		seed := make([]byte, 32)
		for i := range seed {
			seed[i] = byte(i + 1)
		}
		priv := ed25519.NewKeyFromSeed(seed)
		pub := priv.Public().(ed25519.PublicKey)
		pubBytes, err := x509.MarshalPKIXPublicKey(pub)
		if err != nil {
			t.Fatalf("marshal pub: %v", err)
		}
		m.Signature = nil
		payload, err := json.Marshal(m)
		if err != nil {
			t.Fatalf("marshal manifest: %v", err)
		}
		m.Signature = ed25519.Sign(priv, payload)
		if err := manifest.VerifySignature(&m, pubBytes); err != nil {
			t.Fatalf("valid signature rejected: %v", err)
		}
		// Tampering with a signed field must invalidate the signature.
		m.TaskID = m.TaskID + "x"
		if err := manifest.VerifySignature(&m, pubBytes); err == nil {
			t.Fatal("tampered manifest accepted")
		}
	})
}
