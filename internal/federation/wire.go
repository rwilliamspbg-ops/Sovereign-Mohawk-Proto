// Copyright 2026 Sovereign-Mohawk Core Team
// Licensed under the Apache License, Version 2.0
// Wire protocol: binary framing and (de)serialization for GradientMessage.
//
// Frame layout on the wire:
//   [1 byte messageType][4 byte big-endian uint32 payloadLen][payloadLen bytes payload]
// messageType: 0 = single gradient, 1 = batch, 2 = health check
//
// A single-gradient payload is the encoded GradientMessage. A batch payload is
// [4 byte uint32 count][per-gradient: 4 byte uint32 len][encoded GradientMessage]...

package federation

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"time"
)

const (
	msgTypeGradient    byte = 0
	msgTypeBatch       byte = 1
	msgTypeHealthCheck byte = 2
	msgTypeHealthReply byte = 3

	ackOK  byte = 1
	ackErr byte = 0

	// Bounds on untrusted input so a malformed or hostile length prefix can't
	// trigger an unbounded allocation / OOM.
	maxFrameLen    = 512 * 1024 * 1024 // 512MB hard cap on any single frame
	maxStringLen   = 1 << 20           // 1MB per string field
	maxGradientDim = 50_000_000        // 50M float64s (~400MB) per gradient
	maxPathHops    = 10_000
	maxProofLen    = 1 << 20
	maxBatchCount  = 100_000
)

func writeUint32(buf *bytes.Buffer, v uint32) {
	var tmp [4]byte
	binary.BigEndian.PutUint32(tmp[:], v)
	buf.Write(tmp[:])
}

func writeUint64(buf *bytes.Buffer, v uint64) {
	var tmp [8]byte
	binary.BigEndian.PutUint64(tmp[:], v)
	buf.Write(tmp[:])
}

func writeFloat64(buf *bytes.Buffer, v float64) {
	writeUint64(buf, math.Float64bits(v))
}

func writeString(buf *bytes.Buffer, s string) {
	writeUint32(buf, uint32(len(s)))
	buf.WriteString(s)
}

func writeByteSlice(buf *bytes.Buffer, b []byte) {
	writeUint32(buf, uint32(len(b)))
	buf.Write(b)
}

func readUint32(r io.Reader) (uint32, error) {
	var tmp [4]byte
	if _, err := io.ReadFull(r, tmp[:]); err != nil {
		return 0, err
	}
	return binary.BigEndian.Uint32(tmp[:]), nil
}

func readUint64(r io.Reader) (uint64, error) {
	var tmp [8]byte
	if _, err := io.ReadFull(r, tmp[:]); err != nil {
		return 0, err
	}
	return binary.BigEndian.Uint64(tmp[:]), nil
}

func readFloat64(r io.Reader) (float64, error) {
	bits, err := readUint64(r)
	if err != nil {
		return 0, err
	}
	return math.Float64frombits(bits), nil
}

func readBoundedString(r io.Reader) (string, error) {
	n, err := readUint32(r)
	if err != nil {
		return "", err
	}
	if n > maxStringLen {
		return "", fmt.Errorf("string field too large: %d bytes", n)
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(r, buf); err != nil {
		return "", err
	}
	return string(buf), nil
}

func readBoundedBytes(r io.Reader, max uint32) ([]byte, error) {
	n, err := readUint32(r)
	if err != nil {
		return nil, err
	}
	if n > max {
		return nil, fmt.Errorf("byte field too large: %d bytes (max %d)", n, max)
	}
	buf := make([]byte, n)
	if _, err := io.ReadFull(r, buf); err != nil {
		return nil, err
	}
	return buf, nil
}

// encodeGradient serializes a GradientMessage into its wire payload.
func encodeGradient(g *GradientMessage) []byte {
	buf := new(bytes.Buffer)
	writeString(buf, g.GradientID)
	writeString(buf, g.SourceNodeID)
	writeString(buf, g.SourceTierNodeID)
	writeUint64(buf, g.AggregationRound)

	writeUint32(buf, uint32(len(g.GradientData)))
	for _, v := range g.GradientData {
		writeFloat64(buf, v)
	}

	writeFloat64(buf, g.Norm)
	writeUint64(buf, uint64(g.Timestamp.UnixNano()))

	writeUint32(buf, uint32(len(g.PathHops)))
	for _, hop := range g.PathHops {
		writeString(buf, hop)
	}

	writeByteSlice(buf, g.Proof)

	return buf.Bytes()
}

// decodeGradient reads a GradientMessage payload from r. Callers must have
// already established the payload's own length bound (e.g. via a frame
// length prefix) if they want to prevent decodeGradient from reading past a
// logical message boundary on a shared stream.
func decodeGradient(r io.Reader) (*GradientMessage, error) {
	g := &GradientMessage{}
	var err error

	if g.GradientID, err = readBoundedString(r); err != nil {
		return nil, fmt.Errorf("gradient id: %w", err)
	}
	if g.SourceNodeID, err = readBoundedString(r); err != nil {
		return nil, fmt.Errorf("source node id: %w", err)
	}
	if g.SourceTierNodeID, err = readBoundedString(r); err != nil {
		return nil, fmt.Errorf("source tier node id: %w", err)
	}
	if g.AggregationRound, err = readUint64(r); err != nil {
		return nil, fmt.Errorf("aggregation round: %w", err)
	}

	dim, err := readUint32(r)
	if err != nil {
		return nil, fmt.Errorf("dimension count: %w", err)
	}
	if dim > maxGradientDim {
		return nil, fmt.Errorf("gradient dimension too large: %d", dim)
	}
	g.DimensionCount = int(dim)
	g.GradientData = make([]float64, dim)
	for i := range g.GradientData {
		if g.GradientData[i], err = readFloat64(r); err != nil {
			return nil, fmt.Errorf("gradient data[%d]: %w", i, err)
		}
	}

	if g.Norm, err = readFloat64(r); err != nil {
		return nil, fmt.Errorf("norm: %w", err)
	}

	nanos, err := readUint64(r)
	if err != nil {
		return nil, fmt.Errorf("timestamp: %w", err)
	}
	g.Timestamp = time.Unix(0, int64(nanos))

	hopCount, err := readUint32(r)
	if err != nil {
		return nil, fmt.Errorf("path hops count: %w", err)
	}
	if hopCount > maxPathHops {
		return nil, fmt.Errorf("too many path hops: %d", hopCount)
	}
	g.PathHops = make([]string, hopCount)
	for i := range g.PathHops {
		if g.PathHops[i], err = readBoundedString(r); err != nil {
			return nil, fmt.Errorf("path hop[%d]: %w", i, err)
		}
	}

	if g.Proof, err = readBoundedBytes(r, maxProofLen); err != nil {
		return nil, fmt.Errorf("proof: %w", err)
	}

	return g, nil
}

// writeFrame writes a length-prefixed frame: [type][len][payload].
func writeFrame(w io.Writer, msgType byte, payload []byte) error {
	header := make([]byte, 5)
	header[0] = msgType
	binary.BigEndian.PutUint32(header[1:], uint32(len(payload)))
	if _, err := w.Write(header); err != nil {
		return fmt.Errorf("write frame header: %w", err)
	}
	if len(payload) == 0 {
		return nil
	}
	if _, err := w.Write(payload); err != nil {
		return fmt.Errorf("write frame payload: %w", err)
	}
	return nil
}

// readFrameLen reads and bounds-checks a 4-byte payload length prefix.
func readFrameLen(r io.Reader) (uint32, error) {
	n, err := readUint32(r)
	if err != nil {
		return 0, err
	}
	if n > maxFrameLen {
		return 0, fmt.Errorf("frame too large: %d bytes", n)
	}
	return n, nil
}

// limitedPayloadReader returns a reader bounded to exactly n bytes, so a
// decode function can never read past its own payload's frame boundary.
func limitedPayloadReader(r io.Reader, n uint32) io.Reader {
	return io.LimitReader(r, int64(n))
}
