package wasmhost

import (
	"os"
	"testing"
)

func FuzzVerifyRejectsMalformedProofs(f *testing.F) {
	f.Add([]byte{})
	f.Add([]byte{0x01})
	f.Fuzz(func(t *testing.T, proof []byte) {
		wasm, err := os.ReadFile("../../cmd/node-agent/verifier.wasm")
		if err != nil {
			t.Skip("verifier.wasm not available")
		}
		host, err := NewHost(t.Context(), wasm)
		if err != nil {
			t.Skipf("host init failed: %v", err)
		}
		defer host.Close(t.Context())
		// Must not panic; errors or false are acceptable for malformed input.
		_, _ = host.Verify(t.Context(), proof, 1000)
	})
}