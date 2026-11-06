package network

import (
	"context"
	"fmt"
	"sync"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	peer "github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

// Discovery manages peer discovery for a libp2p host. It supports two modes:
//   - Bootstrap: connect to a static list of bootstrap peers (works on any
//     network, including WAN, as long as the peers are reachable).
//   - mDNS: local-network multicast discovery (no bootstrap list needed).
//
// Kademlia DHT-based discovery was considered but introduces a known
// vulnerability (GO-2024-3218, no fix available), so it is intentionally
// not used. Bootstrap + mDNS covers the common cases without that risk.
type Discovery struct {
	host            corehost.Host
	bootstrapPeers  []string
	mu              sync.Mutex
	connectedPeers  map[peer.ID]time.Time
}

// NewDiscovery creates a discovery manager for the given host.
func NewDiscovery(h corehost.Host, bootstrapPeers []string) *Discovery {
	return &Discovery{
		host:           h,
		bootstrapPeers: bootstrapPeers,
		connectedPeers: make(map[peer.ID]time.Time),
	}
}

// Bootstrap connects to all configured bootstrap peers. Returns the number
// of successfully connected peers.
func (d *Discovery) Bootstrap(ctx context.Context) (int, error) {
	if d == nil {
		return 0, fmt.Errorf("discovery not initialized")
	}
	connected := 0
	for _, addr := range d.bootstrapPeers {
		maddr, err := ma.NewMultiaddr(addr)
		if err != nil {
			continue
		}
		info, err := peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			continue
		}
		if err := d.host.Connect(ctx, *info); err != nil {
			continue
		}
		d.mu.Lock()
		d.connectedPeers[info.ID] = time.Now()
		d.mu.Unlock()
		connected++
	}
	if connected == 0 && len(d.bootstrapPeers) > 0 {
		return 0, fmt.Errorf("discovery: failed to connect to any bootstrap peer")
	}
	return connected, nil
}

// ConnectedPeers returns the set of peers discovered/connected so far.
func (d *Discovery) ConnectedPeers() []peer.ID {
	if d == nil {
		return nil
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	out := make([]peer.ID, 0, len(d.connectedPeers))
	for p := range d.connectedPeers {
		out = append(out, p)
	}
	return out
}

// PeerCount returns the number of connected peers.
func (d *Discovery) PeerCount() int {
	if d == nil {
		return 0
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	return len(d.connectedPeers)
}

// Host returns the underlying libp2p host.
func (d *Discovery) Host() corehost.Host { return d.host }

// Close is a no-op kept for API compatibility.
func (d *Discovery) Close() error { return nil }
