package federation

import (
	"bytes"
	"testing"
	"time"
)

// The optimized encoder must produce byte-identical output to the original
// field-by-field loop; only the internal buffering changes.
func TestEncodeGradientIsByteIdenticalToReference(t *testing.T) {
	g := &GradientMessage{
		GradientID:       "grad-1",
		SourceNodeID:     "node-a",
		SourceTierNodeID: "tier-b",
		AggregationRound: 7,
		DimensionCount:   4,
		GradientData:     []float64{1.5, -2.25, 0, 1e300},
		Norm:             3.75,
		Timestamp:        time.Unix(1700000000, 123456789),
		PathHops:         []string{"hop-a", "hop-b"},
		Proof:            []byte{0xde, 0xad, 0xbe, 0xef},
	}

	got := encodeGradient(g)

	// Reference implementation: the original unsized-buffer, per-element loop.
	ref := new(bytes.Buffer)
	writeString(ref, g.GradientID)
	writeString(ref, g.SourceNodeID)
	writeString(ref, g.SourceTierNodeID)
	writeUint64(ref, g.AggregationRound)
	writeUint32(ref, uint32(len(g.GradientData)))
	for _, v := range g.GradientData {
		writeFloat64(ref, v)
	}
	writeFloat64(ref, g.Norm)
	writeUint64(ref, uint64(g.Timestamp.UnixNano()))
	writeUint32(ref, uint32(len(g.PathHops)))
	for _, hop := range g.PathHops {
		writeString(ref, hop)
	}
	writeByteSlice(ref, g.Proof)

	if !bytes.Equal(got, ref.Bytes()) {
		t.Fatalf("encodeGradient diverged from reference\ngot:  %x\nwant: %x", got, ref.Bytes())
	}

	// Round-trip must still decode to an equivalent message.
	decoded, err := decodeGradient(bytes.NewReader(got))
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.GradientID != g.GradientID ||
		decoded.SourceNodeID != g.SourceNodeID ||
		decoded.SourceTierNodeID != g.SourceTierNodeID ||
		decoded.AggregationRound != g.AggregationRound ||
		decoded.DimensionCount != g.DimensionCount ||
		len(decoded.GradientData) != len(g.GradientData) ||
		decoded.Norm != g.Norm ||
		len(decoded.PathHops) != len(g.PathHops) ||
		!bytes.Equal(decoded.Proof, g.Proof) {
		t.Fatalf("round-trip mismatch: %+v", decoded)
	}
	for i := range g.GradientData {
		if decoded.GradientData[i] != g.GradientData[i] {
			t.Fatalf("GradientData[%d] = %v, want %v", i, decoded.GradientData[i], g.GradientData[i])
		}
	}
	if !decoded.Timestamp.Equal(g.Timestamp) {
		t.Fatalf("Timestamp = %v, want %v", decoded.Timestamp, g.Timestamp)
	}
}

// An empty gradient must still encode cleanly.
func TestEncodeGradientEmptyFields(t *testing.T) {
	g := &GradientMessage{}
	got := encodeGradient(g)
	if len(got) == 0 {
		t.Fatal("encoded payload is empty")
	}
	decoded, err := decodeGradient(bytes.NewReader(got))
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.DimensionCount != 0 || len(decoded.PathHops) != 0 {
		t.Fatalf("unexpected decode: %+v", decoded)
	}
}
