package network

import (
	"context"
	"fmt"
	"os"
	"strings"

	libp2p "github.com/libp2p/go-libp2p"
	corehost "github.com/libp2p/go-libp2p/core/host"
	peer "github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

type KEXMode string

const (
	KEXModeX25519               KEXMode = "x25519"
	KEXModeHybridX25519MLKEM768 KEXMode = "x25519-mlkem768-hybrid"
)

func ParseKEXMode(raw string) KEXMode {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "default", "pqc", "pqc-hybrid", string(KEXModeHybridX25519MLKEM768):
		return KEXModeHybridX25519MLKEM768
	case string(KEXModeX25519):
		return KEXModeX25519
	case "hybrid", "ml-kem", "mlkem", "ml-kem-768", "mlkem768":
		return KEXModeHybridX25519MLKEM768
	default:
		return KEXMode("")
	}
}

func ParseKEXModeStrict(raw string) (KEXMode, error) {
	mode := ParseKEXMode(raw)
	if mode == "" {
		return "", fmt.Errorf("unsupported KEX mode %q", raw)
	}
	return mode, nil
}

func SupportedKEXModes() []KEXMode {
	return []KEXMode{KEXModeX25519, KEXModeHybridX25519MLKEM768}
}

func (mode KEXMode) ExpectedPublicKeyBytes() int {
	if mode == KEXModeHybridX25519MLKEM768 {
		return 1216
	}
	return 32
}

type Config struct {
	ListenAddrs        []string
	RelayAddrs         []string
	EnableRelayService bool
	EnableHolePunching bool
	EnableNATPortMap   bool
	ResourceScope      string
	KEXMode            KEXMode
}

func DefaultConfig(port int) Config {
	listenAddrs := []string{
		fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port),
	}
	if !isQUICDisabled() {
		listenAddrs = append(listenAddrs, fmt.Sprintf("/ip4/0.0.0.0/udp/%d/quic-v1", port))
	}

	return Config{
		ListenAddrs:        listenAddrs,
		EnableRelayService: true,
		EnableHolePunching: true,
		EnableNATPortMap:   true,
		ResourceScope:      "regional-shard",
		KEXMode:            KEXModeX25519,
	}
}

func isQUICDisabled() bool {
	raw := strings.ToLower(strings.TrimSpace(os.Getenv("MOHAWK_DISABLE_QUIC")))
	switch raw {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func (cfg Config) Validate() error {
	if ParseKEXMode(string(cfg.KEXMode)) == "" {
		return fmt.Errorf("unsupported KEX mode %q", cfg.KEXMode)
	}
	return nil
}

func (cfg Config) Normalized() (Config, error) {
	mode := ParseKEXMode(string(cfg.KEXMode))
	if mode == "" {
		return cfg, fmt.Errorf("unsupported KEX mode %q", cfg.KEXMode)
	}
	cfg.KEXMode = mode
	return cfg, nil
}

func NewHost(ctx context.Context, cfg Config) (corehost.Host, error) {
	_ = ctx
	normalized, err := cfg.Normalized()
	if err != nil {
		return nil, err
	}
	cfg = normalized
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
