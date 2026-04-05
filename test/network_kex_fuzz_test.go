package test

import (
	"strings"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
)

func TestKEXModeParserNeverInventsUnknownMode(t *testing.T) {
	cases := []string{"", "default", "x25519", "hybrid", "mlkem", "unknown", "X25519-MLKEM768-HYBRID"}
	for _, raw := range cases {
		mode := network.ParseKEXMode(raw)
		if mode == "" {
			continue
		}
		if mode != network.KEXModeX25519 && mode != network.KEXModeHybridX25519MLKEM768 {
			t.Fatalf("unexpected normalized mode for %q: %q", raw, mode)
		}
	}
}

func FuzzParseKEXModeStrict(f *testing.F) {
	f.Add("x25519")
	f.Add("x25519-mlkem768-hybrid")
	f.Add("hybrid")
	f.Add("downgrade-mode")

	f.Fuzz(func(t *testing.T, raw string) {
		mode, err := network.ParseKEXModeStrict(raw)
		normalized := network.ParseKEXMode(raw)
		if err != nil {
			if normalized != "" {
				t.Fatalf("strict parser failed while non-strict returned mode=%q for raw=%q", normalized, raw)
			}
			return
		}
		if mode != normalized {
			t.Fatalf("strict/non-strict mismatch strict=%q normalized=%q raw=%q", mode, normalized, raw)
		}
		if mode != network.KEXModeX25519 && mode != network.KEXModeHybridX25519MLKEM768 {
			t.Fatalf("unexpected mode %q", mode)
		}
		if strings.Contains(strings.ToLower(strings.TrimSpace(raw)), "downgrade") && mode == network.KEXModeX25519 {
			t.Fatal("downgrade-like input unexpectedly normalized to x25519")
		}
	})
}
