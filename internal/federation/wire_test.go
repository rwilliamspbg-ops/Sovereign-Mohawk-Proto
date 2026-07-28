// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Tests for wire.go: encode/decode round-trip and malformed-input handling.

package federation

import (
	"bytes"
	"encoding/binary"
	"testing"
	"time"
)

func TestEncodeDecodeGradientRoundTrip(t *testing.T) {
	original := &GradientMessage{
		GradientID:       "grad-1",
		SourceNodeID:     "node-a",
		SourceTierNodeID: "regional-1",
		AggregationRound: 42,
		DimensionCount:   4,
		GradientData:     []float64{1.5, -2.25, 0, 3.14159},
		Norm:             17.5,
		Timestamp:        time.Unix(1780000000, 123456789),
		PathHops:         []string{"regional-1", "continental-1"},
		Proof:            []byte{0xDE, 0xAD, 0xBE, 0xEF},
	}

	payload := encodeGradient(original)
	decoded, err := decodeGradient(bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("decodeGradient: %v", err)
	}

	if decoded.GradientID != original.GradientID ||
		decoded.SourceNodeID != original.SourceNodeID ||
		decoded.SourceTierNodeID != original.SourceTierNodeID ||
		decoded.AggregationRound != original.AggregationRound ||
		decoded.DimensionCount != original.DimensionCount ||
		decoded.Norm != original.Norm ||
		!decoded.Timestamp.Equal(original.Timestamp) {
		t.Fatalf("scalar fields mismatch: got %+v, want %+v", decoded, original)
	}
	if len(decoded.GradientData) != len(original.GradientData) {
		t.Fatalf("gradient data length mismatch: got %d, want %d", len(decoded.GradientData), len(original.GradientData))
	}
	for i := range original.GradientData {
		if decoded.GradientData[i] != original.GradientData[i] {
			t.Fatalf("gradient data[%d] = %v, want %v", i, decoded.GradientData[i], original.GradientData[i])
		}
	}
	if len(decoded.PathHops) != len(original.PathHops) {
		t.Fatalf("path hops length mismatch")
	}
	for i := range original.PathHops {
		if decoded.PathHops[i] != original.PathHops[i] {
			t.Fatalf("path hop[%d] = %q, want %q", i, decoded.PathHops[i], original.PathHops[i])
		}
	}
	if !bytes.Equal(decoded.Proof, original.Proof) {
		t.Fatalf("proof mismatch: got %x, want %x", decoded.Proof, original.Proof)
	}
}

func TestEncodeDecodeEmptyGradient(t *testing.T) {
	original := &GradientMessage{}
	payload := encodeGradient(original)
	decoded, err := decodeGradient(bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("decodeGradient on empty message: %v", err)
	}
	if len(decoded.GradientData) != 0 || len(decoded.PathHops) != 0 || len(decoded.Proof) != 0 {
		t.Fatalf("expected empty slices, got data=%v hops=%v proof=%v", decoded.GradientData, decoded.PathHops, decoded.Proof)
	}
}

func TestDecodeGradientTruncatedInput(t *testing.T) {
	original := gradMsg("g", []float64{1, 2, 3})
	payload := encodeGradient(original)

	// Truncate at every prefix boundary; decode must error, never panic.
	for cut := 0; cut < len(payload); cut += 3 {
		_, err := decodeGradient(bytes.NewReader(payload[:cut]))
		if err == nil {
			t.Fatalf("expected error decoding truncated payload at cut=%d, got success", cut)
		}
	}
}

func TestDecodeGradientRejectsOversizedDimension(t *testing.T) {
	buf := new(bytes.Buffer)
	writeString(buf, "id")
	writeString(buf, "src")
	writeString(buf, "tier")
	writeUint64(buf, 1)
	writeUint32(buf, maxGradientDim+1) // claims an absurd dimension count
	// deliberately no data following — decode must reject before trying to
	// allocate/read maxGradientDim+1 float64s.

	_, err := decodeGradient(buf)
	if err == nil {
		t.Fatalf("expected error for oversized gradient dimension, got nil")
	}
}

func TestDecodeGradientRejectsOversizedString(t *testing.T) {
	buf := new(bytes.Buffer)
	writeUint32(buf, maxStringLen+1) // GradientID length prefix

	_, err := decodeGradient(buf)
	if err == nil {
		t.Fatalf("expected error for oversized string field, got nil")
	}
}

func TestWriteFrameReadFrameLenRoundTrip(t *testing.T) {
	payload := []byte("hello federation")
	buf := new(bytes.Buffer)
	if err := writeFrame(buf, msgTypeGradient, payload); err != nil {
		t.Fatalf("writeFrame: %v", err)
	}

	msgType := make([]byte, 1)
	if _, err := buf.Read(msgType); err != nil {
		t.Fatalf("read msg type: %v", err)
	}
	if msgType[0] != msgTypeGradient {
		t.Fatalf("msg type = %d, want %d", msgType[0], msgTypeGradient)
	}

	n, err := readFrameLen(buf)
	if err != nil {
		t.Fatalf("readFrameLen: %v", err)
	}
	if int(n) != len(payload) {
		t.Fatalf("frame len = %d, want %d", n, len(payload))
	}
	got := make([]byte, n)
	if _, err := buf.Read(got); err != nil {
		t.Fatalf("read payload: %v", err)
	}
	if !bytes.Equal(got, payload) {
		t.Fatalf("payload = %q, want %q", got, payload)
	}
}

func TestReadFrameLenRejectsOversizedFrame(t *testing.T) {
	buf := new(bytes.Buffer)
	var tmp [4]byte
	binary.BigEndian.PutUint32(tmp[:], maxFrameLen+1)
	buf.Write(tmp[:])

	_, err := readFrameLen(buf)
	if err == nil {
		t.Fatalf("expected error for oversized frame length, got nil")
	}
}
