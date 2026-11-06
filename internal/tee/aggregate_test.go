package tee

import (
	"context"
	"testing"
)

func TestProtectedAggregatorHappyPath(t *testing.T) {
	bin := []byte("agg-kernel-v1")
	m := ComputeMeasurement(PlatformSimulated, bin)
	tm := NewTrustedMeasurements(map[Platform][]string{PlatformSimulated: {m.Digest}})
	p := NewSimulatedProvider(tm)
	agg := NewProtectedAggregator(p, tm, bin)

	out, err := agg.Run(context.Background(), []byte("grads"), func(in []byte) ([]byte, error) {
		return []byte("agg:" + string(in)), nil
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if string(out) != "agg:grads" {
		t.Fatalf("unexpected: %s", out)
	}
}

func TestProtectedAggregatorRejectsUntrusted(t *testing.T) {
	bin := []byte("agg-kernel-v1")
	// trusted list does not contain the real measurement
	tm := NewTrustedMeasurements(map[Platform][]string{PlatformSimulated: {"deadbeef"}})
	p := NewSimulatedProvider(tm)
	agg := NewProtectedAggregator(p, tm, bin)
	_, err := agg.Run(context.Background(), []byte("grads"), func(in []byte) ([]byte, error) {
		return in, nil
	})
	if err == nil {
		t.Fatal("expected attestation failure for untrusted measurement")
	}
}

func TestProtectedAggregatorNilProvider(t *testing.T) {
	agg := NewProtectedAggregator(nil, nil, nil)
	_, err := agg.Run(context.Background(), nil, func(in []byte) ([]byte, error) { return in, nil })
	if err == nil {
		t.Fatal("expected error for nil provider")
	}
}
