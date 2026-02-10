// cmd/node-agent/main.go
package main

import (
	"context"
	"encoding/hex"
	"log"
	"os"

	"sovereign/internal/manifest"
	"sovereign/internal/tpm"
	"sovereign/internal/wasmhost"
)

func main() {
	// Fetch job, manifest, and wasmBytes from MOHAWK API (omitted for brevity).
	var m manifest.Manifest
	var wasmBytes []byte
	var orchestratorPub []byte // load from config or TPM-provisioned blob

	if err := tpm.VerifyNodeState(); err != nil {
		log.Fatalf("TPM verification failed: %v", err)
	}
	if err := manifest.VerifySignature(&m, orchestratorPub); err != nil {
		log.Fatalf("manifest signature invalid: %v", err)
	}

	if !hashMatches(wasmBytes, m.WasmModuleSHA256) {
		log.Fatalf("Wasm hash mismatch, aborting")
	}

	env := &wasmhost.HostEnv{
		Caps: map[manifest.Capability]bool{},
		LogFn: func(level, msg string) {
			log.Printf("[%s] %s", level, msg)
		},
		FLSend: func(payload []byte) error {
			// POST to FL aggregator; apply DP config if needed.
			return nil
		},
	}
	for _, c := range m.Capabilities {
		env.Caps[c] = true
	}

	r := wasmhost.NewRunner()
	ctx := context.Background()
	if err := r.RunTask(ctx, wasmBytes, &m, env); err != nil {
		log.Fatalf("task failed: %v", err)
	}
}

func hashMatches(b []byte, hexSha string) bool {
	sum := sha256Sum(b)
	return hex.EncodeToString(sum) == hexSha
}
