package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestLoadVerifierModule_FailClosedWhenMissingAndFallbackDisabled(t *testing.T) {
	conf := Config{
		WasmModulePath:            filepath.Join(t.TempDir(), "nonexistent_proof_verifier.wasm"),
		AllowInsecureWASMFallback: false,
	}

	wasmBin, err := loadVerifierModule(conf)
	if err == nil {
		t.Fatalf("expected error loading missing WASM module with fallback disabled, got nil error")
	}
	if wasmBin != nil {
		t.Fatalf("expected nil wasmBin on failure, got %d bytes", len(wasmBin))
	}
}

func TestLoadVerifierModule_InsecureFallbackEnabled(t *testing.T) {
	conf := Config{
		WasmModulePath:            filepath.Join(t.TempDir(), "nonexistent_proof_verifier.wasm"),
		AllowInsecureWASMFallback: true,
	}

	wasmBin, err := loadVerifierModule(conf)
	if err != nil {
		t.Fatalf("unexpected error loading missing WASM module with fallback enabled: %v", err)
	}
	expectedFallback := insecureFallbackVerifierModule()
	if !bytes.Equal(wasmBin, expectedFallback) {
		t.Fatalf("expected loaded module to match insecure fallback verifier bytes")
	}
}

func TestLoadVerifierModule_ValidFileLoaded(t *testing.T) {
	tempDir := t.TempDir()
	wasmPath := filepath.Join(tempDir, "valid_proof_verifier.wasm")
	dummyBytes := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	if err := os.WriteFile(wasmPath, dummyBytes, 0644); err != nil {
		t.Fatalf("failed to write dummy WASM file: %v", err)
	}

	conf := Config{
		WasmModulePath:            wasmPath,
		AllowInsecureWASMFallback: false,
	}

	wasmBin, err := loadVerifierModule(conf)
	if err != nil {
		t.Fatalf("unexpected error loading valid WASM module: %v", err)
	}
	if !bytes.Equal(wasmBin, dummyBytes) {
		t.Fatalf("expected loaded module to match file bytes")
	}
}
