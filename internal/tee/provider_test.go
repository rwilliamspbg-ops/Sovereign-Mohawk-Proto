package tee

import (
	"context"
	"testing"
)

func TestPlatformValidity(t *testing.T) {
	for _, p := range AllPlatforms {
		if !p.IsValid() {
			t.Fatalf("expected %s valid", p)
		}
	}
	if Platform("bogus").IsValid() {
		t.Fatal("bogus platform reported valid")
	}
}

func TestTrustedMeasurementsFailClosed(t *testing.T) {
	tm := NewTrustedMeasurements(nil)
	if tm.Accepts(ComputeMeasurement(PlatformSimulated, []byte("x"))) {
		t.Fatal("nil allow-list accepted a measurement")
	}
	if NewTrustedMeasurements(map[Platform][]string{}).Accepts(ComputeMeasurement(PlatformSimulated, []byte("x"))) {
		t.Fatal("empty allow-list accepted a measurement")
	}
}

func TestSimulatedHappyPath(t *testing.T) {
	bin := []byte("enclave-binary-v1")
	m := ComputeMeasurement(PlatformSimulated, bin)
	tm := NewTrustedMeasurements(map[Platform][]string{
		PlatformSimulated: {m.Digest},
	})
	p := NewSimulatedProvider(tm)

	ctx := context.Background()
	if !p.Available(ctx) {
		t.Fatal("simulated provider should be available")
	}
	h, err := p.CreateEnclave(ctx, bin)
	if err != nil {
		t.Fatalf("CreateEnclave: %v", err)
	}
	if h.Measurement.Digest != m.Digest {
		t.Fatalf("measurement mismatch: %s vs %s", h.Measurement.Digest, m.Digest)
	}

	res, err := p.RemoteAttest(ctx, h, []byte("nonce-1"))
	if err != nil || !res.Verified {
		t.Fatalf("attestation failed: %v %s", err, res.Error)
	}

	out, err := p.Run(ctx, h, []byte("input"), func(in []byte) ([]byte, error) {
		return append([]byte("out:"), in...), nil
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if string(out) != "out:input" {
		t.Fatalf("unexpected output: %s", out)
	}
	if err := p.Destroy(ctx, h); err != nil {
		t.Fatalf("Destroy: %v", err)
	}
}

func TestSimulatedRejectsUntrustedMeasurement(t *testing.T) {
	bin := []byte("untrusted-binary")
	m := ComputeMeasurement(PlatformSimulated, bin)
	// allow-list contains a DIFFERENT digest
	tm := NewTrustedMeasurements(map[Platform][]string{
		PlatformSimulated: {"0000000000000000000000000000000000000000000000000000000000000000"},
	})
	p := NewSimulatedProvider(tm)
	ctx := context.Background()
	h, _ := p.CreateEnclave(ctx, bin)
	res, err := p.RemoteAttest(ctx, h, []byte("nonce"))
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if res.Verified {
		t.Fatal("untrusted measurement accepted")
	}
	if m.Digest == "0000..." {
		t.Fatal("test fixture collision")
	}
}

func TestSimulatedRejectsEmptyNonce(t *testing.T) {
	bin := []byte("b")
	m := ComputeMeasurement(PlatformSimulated, bin)
	tm := NewTrustedMeasurements(map[Platform][]string{PlatformSimulated: {m.Digest}})
	p := NewSimulatedProvider(tm)
	ctx := context.Background()
	h, _ := p.CreateEnclave(ctx, bin)
	res, _ := p.RemoteAttest(ctx, h, nil)
	if res.Verified {
		t.Fatal("empty nonce accepted")
	}
}

func TestHardwareStubsUnavailable(t *testing.T) {
	ctx := context.Background()
	for _, p := range []TEEProvider{
		NewSGXProvider(nil),
		NewSEVProvider(nil),
		NewTrustZoneProvider(nil),
	} {
		if p.Available(ctx) {
			t.Fatalf("%s reported available on this host", p.Platform())
		}
		h, err := p.CreateEnclave(ctx, []byte("x"))
		if err == nil {
			t.Fatalf("%s CreateEnclave succeeded without hardware", p.Platform())
		}
		if h.ID != "" {
			t.Fatalf("%s returned non-empty handle on failure", p.Platform())
		}
	}
}
