package wasmhost

import (
	"bytes"
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

func TestValidateModuleLimits_AcceptsReasonableModule(t *testing.T) {
	wasm := minimalWasmWithFunctions(10)
	if err := ValidateModuleLimits(wasm); err != nil {
		t.Fatalf("expected module to pass limits, got %v", err)
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
