package internal

import (
	"context"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tee"
)

func TestAggregatorEnclavePassthrough(t *testing.T) {
	a := NewAggregator(Regional)
	// No TEE configured: passthrough.
	out, err := a.RunAggregationInEnclave(context.Background(), []byte("x"), func(in []byte) ([]byte, error) {
		return []byte("passthrough:" + string(in)), nil
	})
	if err != nil {
		t.Fatalf("passthrough: %v", err)
	}
	if string(out) != "passthrough:x" {
		t.Fatalf("unexpected: %s", out)
	}
	if a.EnclaveAvailable(context.Background()) {
		t.Fatal("expected unavailable without provider")
	}
}

func TestAggregatorEnclaveProtected(t *testing.T) {
	bin := []byte("agg-kernel")
	m := tee.ComputeMeasurement(tee.PlatformSimulated, bin)
	tm := tee.NewTrustedMeasurements(map[tee.Platform][]string{tee.PlatformSimulated: {m.Digest}})
	p := tee.NewSimulatedProvider(tm)

	a := NewAggregator(Regional)
	a.TEEProvider = p
	a.TEETrusted = tm
	a.TEEBinary = bin

	if !a.EnclaveAvailable(context.Background()) {
		t.Fatal("expected available")
	}
	out, err := a.RunAggregationInEnclave(context.Background(), []byte("grads"), func(in []byte) ([]byte, error) {
		return []byte("agg:" + string(in)), nil
	})
	if err != nil {
		t.Fatalf("protected: %v", err)
	}
	if string(out) != "agg:grads" {
		t.Fatalf("unexpected: %s", out)
	}
}
