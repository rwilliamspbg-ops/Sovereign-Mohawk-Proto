package test

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
)

// TestSwarmRuntimeProfileFromEnv runs one runtime swarm profile based on env vars.
// It is designed for CI matrix execution with configurable node counts and timeout wrappers.
func TestSwarmRuntimeProfileFromEnv(t *testing.T) {
	nodeCount := readIntEnv(t, "MOHAWK_SWARM_NODE_COUNT", 500)
	maliciousRatio := readFloatEnv(t, "MOHAWK_SWARM_MALICIOUS_RATIO", 0.44)
	expectFailure := readBoolEnv("MOHAWK_SWARM_EXPECT_FAILURE", false)

	if nodeCount < 1 {
		t.Fatalf("invalid MOHAWK_SWARM_NODE_COUNT: %d", nodeCount)
	}
	if maliciousRatio < 0 || maliciousRatio > 0.99 {
		t.Fatalf("invalid MOHAWK_SWARM_MALICIOUS_RATIO: %.4f", maliciousRatio)
	}

	malicious := int(float64(nodeCount) * maliciousRatio)
	honest := nodeCount - malicious
	if honest < 0 {
		honest = 0
	}

	agg := batch.NewAggregator(&batch.Config{
		TotalNodes:       nodeCount,
		HonestNodes:      honest,
		MaliciousNodes:   malicious,
		RedundancyFactor: 10,
	})
	err := agg.ProcessRound(batch.ModeByzantineMix)

	if expectFailure {
		if err == nil {
			t.Fatalf("expected failure for profile nodes=%d ratio=%.4f, got success", nodeCount, maliciousRatio)
		}
		return
	}

	if err != nil {
		t.Fatalf("expected success for profile nodes=%d ratio=%.4f, got error=%v", nodeCount, maliciousRatio, err)
	}
}

func readIntEnv(t *testing.T, key string, fallback int) int {
	t.Helper()
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(raw)
	if err != nil {
		t.Fatalf("invalid integer in %s=%q: %v", key, raw, err)
	}
	return parsed
}

func readFloatEnv(t *testing.T, key string, fallback float64) float64 {
	t.Helper()
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	parsed, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		t.Fatalf("invalid float in %s=%q: %v", key, raw, err)
	}
	return parsed
}

func readBoolEnv(key string, fallback bool) bool {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if raw == "" {
		return fallback
	}
	switch raw {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		panic(fmt.Sprintf("invalid boolean in %s=%q", key, raw))
	}
}
