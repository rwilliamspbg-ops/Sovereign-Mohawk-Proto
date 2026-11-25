package network

import (
	"context"
	"strings"
	"testing"

	corehost "github.com/libp2p/go-libp2p/core/host"
)

// newNetworkTestHost starts a libp2p host bound to an ephemeral loopback port.
func newNetworkTestHost(t *testing.T) corehost.Host {
	t.Helper()
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	h, err := NewHost(context.Background(), cfg)
	if err != nil {
		t.Fatalf("NewHost: %v", err)
	}
	t.Cleanup(func() { _ = h.Close() })
	return h
}

// peerAddr returns a /p2p-terminated multiaddr string for h, suitable for
// Discovery.Bootstrap and parseRelays.
func peerAddr(h corehost.Host) string {
	addr := h.Addrs()[0].String()
	if strings.Contains(addr, "/p2p/") {
		return addr
	}
	return addr + "/p2p/" + h.ID().String()
}

func TestParseKEXMode(t *testing.T) {
	hybrid := KEXModeHybridX25519MLKEM768
	cases := []struct {
		raw  string
		want KEXMode
	}{
		{"", hybrid},
		{"default", hybrid},
		{"pqc", hybrid},
		{"pqc-hybrid", hybrid},
		{"x25519-mlkem768-hybrid", hybrid},
		{"hybrid", hybrid},
		{"ml-kem", hybrid},
		{"mlkem", hybrid},
		{"ml-kem-768", hybrid},
		{"mlkem768", hybrid},
		{"X25519", KEXModeX25519},
		{"  x25519  ", KEXModeX25519},
		{"bogus", ""},
	}
	for _, tc := range cases {
		t.Run(tc.raw, func(t *testing.T) {
			if got := ParseKEXMode(tc.raw); got != tc.want {
				t.Errorf("ParseKEXMode(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestParseAggregationMode(t *testing.T) {
	cases := []struct {
		raw  string
		want AggregationMode
	}{
		{"", AggregationModePlaintext},
		{"default", AggregationModePlaintext},
		{"plaintext", AggregationModePlaintext},
		{"PLAINTEXT", AggregationModePlaintext},
		{"fhe_threshold_v1", AggregationModeFHEThreshold},
		{"fhe", AggregationModeFHEThreshold},
		{"tfhe", AggregationModeFHEThreshold},
		{"threshold-fhe", AggregationModeFHEThreshold},
		{"bogus", ""},
	}
	for _, tc := range cases {
		t.Run(tc.raw, func(t *testing.T) {
			if got := ParseAggregationMode(tc.raw); got != tc.want {
				t.Errorf("ParseAggregationMode(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestSupportedModes(t *testing.T) {
	kex := SupportedKEXModes()
	if len(kex) != 2 || !containsKEXMode(kex, KEXModeX25519) || !containsKEXMode(kex, KEXModeHybridX25519MLKEM768) {
		t.Errorf("SupportedKEXModes() = %v, want both supported modes", kex)
	}
	agg := SupportedAggregationModes()
	if len(agg) != 2 || !containsAggregationMode(agg, AggregationModePlaintext) || !containsAggregationMode(agg, AggregationModeFHEThreshold) {
		t.Errorf("SupportedAggregationModes() = %v, want both supported modes", agg)
	}
}

func containsKEXMode(xs []KEXMode, want KEXMode) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

func containsAggregationMode(xs []AggregationMode, want AggregationMode) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

func TestParseKEXModeStrict(t *testing.T) {
	mode, err := ParseKEXModeStrict("x25519")
	if err != nil {
		t.Fatalf("ParseKEXModeStrict(valid): %v", err)
	}
	if mode != KEXModeX25519 {
		t.Errorf("mode = %q, want x25519", mode)
	}

	_, err = ParseKEXModeStrict("bogus")
	if err == nil {
		t.Fatal("expected an error for an unsupported mode")
	}
	if !strings.Contains(err.Error(), `unsupported KEX mode "bogus"`) {
		t.Errorf("error = %q, want it to quote the unsupported mode", err)
	}
}

func TestExpectedPublicKeyBytes(t *testing.T) {
	cases := []struct {
		mode KEXMode
		want int
	}{
		{KEXModeX25519, 32},
		{KEXModeHybridX25519MLKEM768, 1216},
		{KEXMode(""), 32},
	}
	for _, tc := range cases {
		if got := tc.mode.ExpectedPublicKeyBytes(); got != tc.want {
			t.Errorf("ExpectedPublicKeyBytes(%q) = %d, want %d", tc.mode, got, tc.want)
		}
	}
}

func TestIsQUICDisabled(t *testing.T) {
	cases := []struct {
		raw  string
		want bool
	}{
		{"1", true},
		{"true", true},
		{"TRUE", true},
		{"yes", true},
		{"on", true},
		{"0", false},
		{"false", false},
		{"no", false},
		{"off", false},
		{"", false},
		{"random", false},
	}
	for _, tc := range cases {
		t.Run("env="+tc.raw, func(t *testing.T) {
			t.Setenv("MOHAWK_DISABLE_QUIC", tc.raw)
			if got := isQUICDisabled(); got != tc.want {
				t.Errorf("isQUICDisabled(%q) = %v, want %v", tc.raw, got, tc.want)
			}
		})
	}
}

func TestDefaultConfig(t *testing.T) {
	t.Setenv("MOHAWK_DISABLE_QUIC", "")
	cfg := DefaultConfig(4201)
	if len(cfg.ListenAddrs) != 2 {
		t.Fatalf("ListenAddrs = %v, want tcp and quic entries", cfg.ListenAddrs)
	}
	if cfg.ListenAddrs[0] != "/ip4/0.0.0.0/tcp/4201" {
		t.Errorf("tcp listen addr = %q", cfg.ListenAddrs[0])
	}
	if cfg.ListenAddrs[1] != "/ip4/0.0.0.0/udp/4201/quic-v1" {
		t.Errorf("quic listen addr = %q", cfg.ListenAddrs[1])
	}
	if cfg.KEXMode != KEXModeX25519 {
		t.Errorf("KEXMode = %q, want x25519", cfg.KEXMode)
	}
	if cfg.AggregationMode != AggregationModePlaintext {
		t.Errorf("AggregationMode = %q, want plaintext", cfg.AggregationMode)
	}
	if !cfg.EnableRelayService || !cfg.EnableHolePunching || !cfg.EnableNATPortMap {
		t.Errorf("relay/hole-punch/NAT-port-map should default on: %+v", cfg)
	}
	if cfg.ResourceScope != "regional-shard" {
		t.Errorf("ResourceScope = %q, want regional-shard", cfg.ResourceScope)
	}

	t.Setenv("MOHAWK_DISABLE_QUIC", "1")
	cfg = DefaultConfig(4202)
	if len(cfg.ListenAddrs) != 1 || cfg.ListenAddrs[0] != "/ip4/0.0.0.0/tcp/4202" {
		t.Errorf("ListenAddrs with QUIC disabled = %v", cfg.ListenAddrs)
	}
}

func TestConfigValidate(t *testing.T) {
	if err := DefaultConfig(0).Validate(); err != nil {
		t.Errorf("default config: %v", err)
	}

	cases := []struct {
		name    string
		mutate  func(*Config)
		wantErr string
	}{
		{"unsupported kex mode", func(c *Config) { c.KEXMode = "bogus" }, "unsupported KEX mode"},
		{"unsupported aggregation mode", func(c *Config) { c.AggregationMode = "bogus" }, "unsupported aggregation mode"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := DefaultConfig(0)
			tc.mutate(&cfg)
			err := cfg.Validate()
			if err == nil {
				t.Fatalf("expected an error containing %q", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
		})
	}
}

func TestConfigNormalized(t *testing.T) {
	t.Run("aliases are canonicalized", func(t *testing.T) {
		cfg := Config{KEXMode: "hybrid", AggregationMode: "fhe"}
		got, err := cfg.Normalized()
		if err != nil {
			t.Fatalf("Normalized: %v", err)
		}
		if got.KEXMode != KEXModeHybridX25519MLKEM768 {
			t.Errorf("KEXMode = %q, want the hybrid mode", got.KEXMode)
		}
		if got.AggregationMode != AggregationModeFHEThreshold {
			t.Errorf("AggregationMode = %q, want the FHE threshold mode", got.AggregationMode)
		}
	})

	t.Run("empty modes take defaults", func(t *testing.T) {
		got, err := Config{}.Normalized()
		if err != nil {
			t.Fatalf("Normalized: %v", err)
		}
		if got.KEXMode != KEXModeHybridX25519MLKEM768 {
			t.Errorf("KEXMode = %q, want the hybrid default", got.KEXMode)
		}
		if got.AggregationMode != AggregationModePlaintext {
			t.Errorf("AggregationMode = %q, want plaintext", got.AggregationMode)
		}
	})

	cases := []struct {
		name    string
		cfg     Config
		wantErr string
	}{
		{"unsupported kex mode", Config{KEXMode: "bogus", AggregationMode: "plaintext"}, "unsupported KEX mode"},
		{"unsupported aggregation mode", Config{KEXMode: "x25519", AggregationMode: "bogus"}, "unsupported aggregation mode"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := tc.cfg.Normalized()
			if err == nil {
				t.Fatalf("expected an error containing %q", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
		})
	}
}

func TestNewHostRejectsInvalidConfiguration(t *testing.T) {
	base := func() Config {
		cfg := DefaultConfig(0)
		cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
		return cfg
	}

	cases := []struct {
		name    string
		mutate  func(*Config)
		wantErr string
	}{
		{"unsupported kex mode", func(c *Config) { c.KEXMode = "bogus" }, "unsupported KEX mode"},
		{"unsupported aggregation mode", func(c *Config) { c.AggregationMode = "bogus" }, "unsupported aggregation mode"},
		{"invalid relay multiaddr", func(c *Config) { c.RelayAddrs = []string{"not-a-multiaddr"} }, "invalid relay multiaddr"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := base()
			tc.mutate(&cfg)
			h, err := NewHost(context.Background(), cfg)
			if err == nil {
				if h != nil {
					_ = h.Close()
				}
				t.Fatalf("expected an error containing %q", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tc.wantErr)
			}
		})
	}
}

func TestNewHostAcceptsValidRelay(t *testing.T) {
	h := newNetworkTestHost(t)
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	cfg.RelayAddrs = []string{peerAddr(h)}

	host, err := NewHost(context.Background(), cfg)
	if err != nil {
		t.Fatalf("NewHost with a valid relay: %v", err)
	}
	_ = host.Close()
}

func TestParseRelays(t *testing.T) {
	h := newNetworkTestHost(t)

	t.Run("valid", func(t *testing.T) {
		peers, err := parseRelays([]string{peerAddr(h)})
		if err != nil {
			t.Fatalf("parseRelays: %v", err)
		}
		if len(peers) != 1 {
			t.Fatalf("len = %d, want 1", len(peers))
		}
		if peers[0].ID != h.ID() {
			t.Errorf("peer ID = %q, want %q", peers[0].ID, h.ID())
		}
	})

	t.Run("invalid multiaddr", func(t *testing.T) {
		if _, err := parseRelays([]string{"not-a-multiaddr"}); err == nil {
			t.Fatal("expected an error for a malformed multiaddr")
		}
	})

	t.Run("missing p2p component", func(t *testing.T) {
		if _, err := parseRelays([]string{"/ip4/127.0.0.1/tcp/4101"}); err == nil {
			t.Fatal("expected an error when the multiaddr carries no /p2p peer ID")
		}
	})
}

func TestNewHostAnnounceAddrsOverrideAdvertisedAddrs(t *testing.T) {
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	cfg.AnnounceAddrs = []string{"/ip4/203.0.113.10/tcp/4101"}
	h, err := NewHost(context.Background(), cfg)
	if err != nil {
		t.Fatalf("NewHost: %v", err)
	}
	t.Cleanup(func() { _ = h.Close() })

	addrs := h.Addrs()
	if len(addrs) != 1 || addrs[0].String() != "/ip4/203.0.113.10/tcp/4101" {
		t.Fatalf("advertised addrs = %v, want [/ip4/203.0.113.10/tcp/4101]", addrs)
	}
}

func TestNewHostRejectsInvalidAnnounceAddr(t *testing.T) {
	cfg := DefaultConfig(0)
	cfg.ListenAddrs = []string{"/ip4/127.0.0.1/tcp/0"}
	cfg.AnnounceAddrs = []string{"not-a-multiaddr"}
	if _, err := NewHost(context.Background(), cfg); err == nil {
		t.Fatal("NewHost accepted an invalid announce address")
	}
}
