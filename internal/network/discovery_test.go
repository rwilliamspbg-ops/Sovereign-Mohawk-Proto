package network

import (
	"context"
	"testing"
)

func TestDiscoveryCreate(t *testing.T) {
	ctx := context.Background()
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	h, err := NewHost(ctx, cfg)
	if err != nil {
		t.Fatalf("NewHost: %v", err)
	}
	defer h.Close()

	d := NewDiscovery(h, nil)
	if d == nil {
		t.Fatal("expected non-nil discovery")
	}
	if d.PeerCount() != 0 {
		t.Fatalf("expected 0 peers, got %d", d.PeerCount())
	}
	if d.Host() != h {
		t.Fatal("host mismatch")
	}
	if err := d.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}
}

func TestDiscoveryBootstrapEmpty(t *testing.T) {
	ctx := context.Background()
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	h, err := NewHost(ctx, cfg)
	if err != nil {
		t.Fatalf("NewHost: %v", err)
	}
	defer h.Close()

	d := NewDiscovery(h, nil)
	n, err := d.Bootstrap(ctx)
	if err != nil {
		t.Fatalf("Bootstrap: %v", err)
	}
	if n != 0 {
		t.Fatalf("expected 0 connected, got %d", n)
	}
}

func TestDiscoveryBootstrapBadPeer(t *testing.T) {
	ctx := context.Background()
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	h, err := NewHost(ctx, cfg)
	if err != nil {
		t.Fatalf("NewHost: %v", err)
	}
	defer h.Close()

	d := NewDiscovery(h, []string{"/ip4/127.0.0.1/tcp/9999/p2p/12D3KooWTest"})
	n, err := d.Bootstrap(ctx)
	if err == nil {
		t.Fatal("expected error when no peers connect")
	}
	if n != 0 {
		t.Fatalf("expected 0 connected, got %d", n)
	}
}

func TestDiscoveryNilSafety(t *testing.T) {
	var d *Discovery
	if err := d.Close(); err != nil {
		t.Fatalf("nil close: %v", err)
	}
	if d.PeerCount() != 0 {
		t.Fatal("expected 0")
	}
}
