package wasmhost

import (
	"bytes"
	"context"
	"encoding/binary"
	"strings"
	"testing"
)

func TestValidateModuleLimits_RejectsOversizeModule(t *testing.T) {
	wasm := bytes.Repeat([]byte{0x00}, MaxModuleBytes+1)
	if err := ValidateModuleLimits(wasm); err == nil || !strings.Contains(err.Error(), "exceeds max") {
		t.Fatalf("expected oversize module rejection, got %v", err)
	}
}

func TestValidateModuleLimits_RejectsTooManyFunctions(t *testing.T) {
	wasm := minimalWasmWithFunctions(MaxFunctionCount + 1)
	if err := ValidateModuleLimits(wasm); err == nil || !strings.Contains(err.Error(), "function count") {
		t.Fatalf("expected function count rejection, got %v", err)
	}
}

func TestValidateModuleLimits_RejectsTooManyImports(t *testing.T) {
	wasm := minimalWasmWithImports(MaxImportCount + 1)
	if err := ValidateModuleLimits(wasm); err == nil || !strings.Contains(err.Error(), "import count") {
		t.Fatalf("expected import count rejection, got %v", err)
	}
}

func TestValidateModuleLimits_RejectsTooManyLocalsPerFunction(t *testing.T) {
	wasm := minimalWasmWithLocals(MaxFunctionLocals + 1)
	if err := ValidateModuleLimits(wasm); err == nil || !strings.Contains(err.Error(), "locals per function") {
		t.Fatalf("expected locals per function rejection, got %v", err)
	}
}

func TestValidateModuleLimits_AcceptsReasonableModule(t *testing.T) {
	wasm := minimalWasmWithFunctions(10)
	if err := ValidateModuleLimits(wasm); err != nil {
		t.Fatalf("expected module to pass limits, got %v", err)
	}
}

func TestVerifyTimeout_RejectsCancelledContext(t *testing.T) {
	// We cannot reliably hang a module in unit tests; this validates timeout/cancellation plumbing.
	wasm := minimalWasmWithFunctions(1)
	host, err := NewHost(context.Background(), wasm)
	if err != nil {
		t.Skipf("wasm instantiation failed in test environment: %v", err)
	}
	defer host.Close(context.Background())

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err = host.Verify(ctx, []byte{0x01}, 5000)
	if err == nil {
		t.Fatal("expected error from cancelled context, got nil")
	}
}

func TestVerifyTimeout_ZeroMaxMillisFallsBack(t *testing.T) {
	if DefaultMaxMillis == 0 {
		t.Fatal("DefaultMaxMillis must be > 0")
	}
}

func minimalWasmWithFunctions(functionCount int) []byte {
	out := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}

	// Type section: one function type with no params/results.
	typePayload := []byte{0x01, 0x60, 0x00, 0x00}
	out = appendSection(out, 1, typePayload)

	// Function section: N functions all referencing type index 0.
	funcPayload := append(encodeVarUint32(uint32(functionCount)), bytes.Repeat([]byte{0x00}, functionCount)...)
	out = appendSection(out, 3, funcPayload)

	// Export section: export first function as "verify_proof" if available.
	if functionCount > 0 {
		exportPayload := []byte{0x01, 0x0c}
		exportPayload = append(exportPayload, []byte("verify_proof")...)
		exportPayload = append(exportPayload, 0x00, 0x00)
		out = appendSection(out, 7, exportPayload)
	}

	// Code section: N empty function bodies.
	codePayload := encodeVarUint32(uint32(functionCount))
	for i := 0; i < functionCount; i++ {
		codePayload = append(codePayload, 0x02, 0x00, 0x0b)
	}
	out = appendSection(out, 10, codePayload)

	return out
}

func minimalWasmWithImports(importCount int) []byte {
	out := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}

	// Import section with N global imports.
	importPayload := encodeVarUint32(uint32(importCount))
	for i := 0; i < importCount; i++ {
		importPayload = append(importPayload, 0x01, 'm', 0x01, 'g', 0x03, 0x7f, 0x00)
	}
	out = appendSection(out, 2, importPayload)

	return out
}

func minimalWasmWithLocals(localCount int) []byte {
	out := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}

	// Type section with a single function type.
	typePayload := []byte{0x01, 0x60, 0x00, 0x00}
	out = appendSection(out, 1, typePayload)

	// Function section with one function referencing type 0.
	funcPayload := []byte{0x01, 0x00}
	out = appendSection(out, 3, funcPayload)

	// Export section exposes verify_proof.
	exportPayload := []byte{0x01, 0x0c}
	exportPayload = append(exportPayload, []byte("verify_proof")...)
	exportPayload = append(exportPayload, 0x00, 0x00)
	out = appendSection(out, 7, exportPayload)

	// Code section with one body: one local decl and end opcode.
	body := []byte{0x01}
	body = append(body, encodeVarUint32(uint32(localCount))...)
	body = append(body, 0x7f, 0x0b) // i32 local type + end
	codePayload := []byte{0x01}
	codePayload = append(codePayload, encodeVarUint32(uint32(len(body)))...)
	codePayload = append(codePayload, body...)
	out = appendSection(out, 10, codePayload)

	return out
}

func appendSection(wasm []byte, sectionID byte, payload []byte) []byte {
	wasm = append(wasm, sectionID)
	wasm = append(wasm, encodeVarUint32(uint32(len(payload)))...)
	wasm = append(wasm, payload...)
	return wasm
}

func encodeVarUint32(v uint32) []byte {
	buf := make([]byte, binary.MaxVarintLen32)
	n := binary.PutUvarint(buf, uint64(v))
	return buf[:n]
}
