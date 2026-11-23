package network

import (
	"context"
	"testing"
	"time"

	"github.com/libp2p/go-libp2p/core/peer"
)

func TestDiscoveryHandlePeerFoundRecordsPeer(t *testing.T) {
	h := newNetworkTestHost(t)
	d := NewDiscovery(h, nil)

	(&mdnsNotifee{d: d}).HandlePeerFound(peer.AddrInfo{ID: h.ID(), Addrs: h.Addrs()})

	if got := d.PeerCount(); got != 1 {
		t.Fatalf("PeerCount = %d, want 1", got)
	}
	peers := d.ConnectedPeers()
	if len(peers) != 1 {
		t.Fatalf("ConnectedPeers returned %d peers, want 1", len(peers))
	}
	if peers[0] != h.ID() {
		t.Errorf("ConnectedPeers[0] = %q, want %q", peers[0], h.ID())
	}
}

func TestConnectedPeersReturnsCopy(t *testing.T) {
	var nilD *Discovery
	if got := nilD.ConnectedPeers(); got != nil {
		t.Errorf("nil receiver: ConnectedPeers = %v, want nil", got)
	}
	if got := nilD.PeerCount(); got != 0 {
		t.Errorf("nil receiver: PeerCount = %d, want 0", got)
	}

	d := &Discovery{connectedPeers: map[peer.ID]time.Time{}}
	got := d.ConnectedPeers()
	if got == nil {
		t.Fatal("empty discovery: ConnectedPeers = nil, want a non-nil empty slice")
	}
	if len(got) != 0 {
		t.Fatalf("len = %d, want 0", len(got))
	}
	got = append(got, peer.ID("mutated"))
	if d.PeerCount() != 0 {
		t.Error("mutating the returned slice changed the discovery's peer set")
	}
}

func TestDiscoveryNilReceiverGuards(t *testing.T) {
	var d *Discovery
	if n, err := d.Bootstrap(context.Background()); err == nil || n != 0 {
		t.Errorf("Bootstrap on nil = (%d, %v), want (0, error)", n, err)
	}
	if err := d.StartMDNS(context.Background(), "svc"); err == nil {
		t.Error("StartMDNS on nil: expected an error")
	}
	// Host() has no nil-receiver guard (unlike the other methods), so it is
	// intentionally not called on a nil Discovery here.
}

func TestDiscoveryBootstrapSkipsInvalidAddrs(t *testing.T) {
	target := newNetworkTestHost(t)
	host := newNetworkTestHost(t)
	d := NewDiscovery(host, []string{"not-a-multiaddr", peerAddr(target)})

	n, err := d.Bootstrap(context.Background())
	if err != nil {
		t.Fatalf("Bootstrap: %v", err)
	}
	if n != 1 {
		t.Fatalf("connected = %d, want 1 (only the valid peer)", n)
	}
	if d.PeerCount() != 1 {
		t.Errorf("PeerCount = %d, want 1", d.PeerCount())
	}
}

func TestDiscoveryBootstrapAllInvalidReturnsError(t *testing.T) {
	host := newNetworkTestHost(t)
	d := NewDiscovery(host, []string{"not-a-multiaddr", "/ip4/127.0.0.1/tcp/1"})

	n, err := d.Bootstrap(context.Background())
	if err == nil {
		t.Fatal("expected an error when no bootstrap peer can be connected")
	}
	if n != 0 {
		t.Errorf("connected = %d, want 0", n)
	}
}
