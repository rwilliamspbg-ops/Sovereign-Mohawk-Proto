package network

import (
	"context"
	"fmt"
	"sync"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	peer "github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns"
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
	mdnsService     mdns.Service
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

// StartMDNS begins local-network multicast discovery. Discovered peers are
// recorded in ConnectedPeers. Returns an error if the service cannot start.
func (d *Discovery) StartMDNS(ctx context.Context, serviceName string) error {
	if d == nil {
		return fmt.Errorf("discovery not initialized")
	}
	if serviceName == "" {
		serviceName = "mohawk"
	}
	notifee := &mdnsNotifee{d: d}
	svc := mdns.NewMdnsService(d.host, serviceName, notifee)
	if svc == nil {
		return fmt.Errorf("mdns: failed to start service")
	}
	d.mu.Lock()
	d.mdnsService = svc
	d.mu.Unlock()
	return nil
}

// StopMDNS stops the multicast discovery service.
func (d *Discovery) StopMDNS() error {
	if d == nil {
		return nil
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.mdnsService != nil {
		err := d.mdnsService.Close()
		d.mdnsService = nil
		return err
	}
	return nil
}

type mdnsNotifee struct {
	d *Discovery
}

func (n *mdnsNotifee) HandlePeerFound(pi peer.AddrInfo) {
	n.d.mu.Lock()
	defer n.d.mu.Unlock()
	n.d.connectedPeers[pi.ID] = time.Now()
	// Best-effort connect
	_ = n.d.host.Connect(context.Background(), pi)
}
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
