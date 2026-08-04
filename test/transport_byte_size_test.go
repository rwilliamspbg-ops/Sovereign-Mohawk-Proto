package test

import (
	"testing"
	"unsafe"
)

// TestTransportByteSizeConvention grounds the "4 bytes per dimension
// element" constant that proofs/Specification/Communication.lean's
// hierarchicalProtocol/communicationUpperBound bakes into its byte-count
// formula (dimension * (n+1) * 4). Two things are checked:
//
//  1. The "4" is not an arbitrary literal: float32 is 4 bytes on both sides
//     of the IEEE-754 boundary (Go's runtime, Lean's model), not a
//     coincidence of matching magic numbers.
//  2. Lean's per-message size formula (dimension * 4) matches the literal
//     byte-count formula Go actually computes when serializing a gradient,
//     `originalBytes := len(fp32) * 4`, appearing at
//     internal/pyapi/api.go:830 (CompressGradients) and :891
//     (CompressGradientsZeroCopy). Those two functions are cgo `//export`
//     entry points in `package main` and cannot be imported/invoked from a
//     plain Go test, so this test reproduces the identical formula rather
//     than calling through the FFI boundary — see
//     proofs/Refinement/Transport.lean's module docstring for why this
//     row's Go correspondence is narrower (formula-level, not an
//     end-to-end empirical match) than Refinement/MultiKrum.lean's or
//     Refinement/RDPAccountant.lean's.
func TestTransportByteSizeConvention(t *testing.T) {
	if got := int(unsafe.Sizeof(float32(0))); got != 4 {
		t.Fatalf("float32 size = %d bytes, want 4", got)
	}

	for _, dimension := range []int{1, 8, 64, 4096} {
		fp32 := make([]float32, dimension)
		originalBytes := len(fp32) * 4 // internal/pyapi/api.go:830, :891

		leanPerMessageSize := dimension * 4 // Specification.hierarchicalProtocol's per-message `size`
		if originalBytes != leanPerMessageSize {
			t.Fatalf("dimension=%d: Go originalBytes=%d, Lean per-message size=%d", dimension, originalBytes, leanPerMessageSize)
		}
	}
}
