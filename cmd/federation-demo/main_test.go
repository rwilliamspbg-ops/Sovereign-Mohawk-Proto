package main

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/federation"
)

func TestTierLevelFromName(t *testing.T) {
	cases := map[string]federation.TierLevel{
		"regional":    federation.TierRegional,
		"continental": federation.TierContinental,
		"global":      federation.TierGlobal,
		"unknown":     federation.TierRegional,
	}
	for name, want := range cases {
		if got := tierLevelFromName(name); got != want {
			t.Fatalf("tierLevelFromName(%q) = %v, want %v", name, got, want)
		}
	}
}
