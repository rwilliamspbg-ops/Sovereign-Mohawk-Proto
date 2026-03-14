package network

import (
	"context"
	"fmt"

	libp2p "github.com/libp2p/go-libp2p"
	corehost "github.com/libp2p/go-libp2p/core/host"
	peer "github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

type Config struct {
	ListenAddrs        []string
	RelayAddrs         []string
	EnableRelayService bool
	EnableHolePunching bool
	EnableNATPortMap   bool
	ResourceScope      string
}

func DefaultConfig(port int) Config {
	return Config{
		ListenAddrs: []string{
			fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port),
			fmt.Sprintf("/ip4/0.0.0.0/udp/%d/quic-v1", port),
		},
		EnableRelayService: true,
		EnableHolePunching: true,
		EnableNATPortMap:   true,
		ResourceScope:      "regional-shard",
	}
}

func NewHost(ctx context.Context, cfg Config) (corehost.Host, error) {
	_ = ctx
	options := []libp2p.Option{}
	if len(cfg.ListenAddrs) > 0 {
		options = append(options, libp2p.ListenAddrStrings(cfg.ListenAddrs...))
	}
	if cfg.EnableNATPortMap {
		options = append(options, libp2p.NATPortMap())
	}
	if cfg.EnableRelayService {
		options = append(options, libp2p.EnableRelayService())
	}
	if cfg.EnableHolePunching {
		options = append(options, libp2p.EnableHolePunching())
	}

	if len(cfg.RelayAddrs) > 0 {
		peers, err := parseRelays(cfg.RelayAddrs)
		if err != nil {
			return nil, err
		}
		options = append(options, libp2p.EnableAutoRelayWithStaticRelays(peers))
	}

	return libp2p.New(options...)
}

func parseRelays(addrs []string) ([]peer.AddrInfo, error) {
	peers := make([]peer.AddrInfo, 0, len(addrs))
	for _, addr := range addrs {
		maddr, err := ma.NewMultiaddr(addr)
		if err != nil {
			return nil, fmt.Errorf("invalid relay multiaddr %q: %w", addr, err)
		}
		info, err := peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			return nil, fmt.Errorf("invalid relay peer addr %q: %w", addr, err)
		}
		peers = append(peers, *info)
	}
	return peers, nil
}
