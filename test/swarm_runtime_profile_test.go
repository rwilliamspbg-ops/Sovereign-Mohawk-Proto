package test

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/batch"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

// TestSwarmRuntimeProfileFromEnv runs one runtime swarm profile based on env vars.
// It is designed for CI matrix execution with configurable node counts and timeout wrappers.
func TestSwarmRuntimeProfileFromEnv(t *testing.T) {
	nodeCount := readIntEnv(t, "MOHAWK_SWARM_NODE_COUNT", 500)
	maliciousRatio := readFloatEnv(t, "MOHAWK_SWARM_MALICIOUS_RATIO", 0.44)
	expectFailure := readBoolEnv("MOHAWK_SWARM_EXPECT_FAILURE", false)
	localEpochs := readIntEnv(t, "MOHAWK_FEDAVG_LOCAL_EPOCHS", 1)
	participation := readFloatEnv(t, "MOHAWK_FEDAVG_PARTICIPATION", 1.0)
	roundLabel := strings.TrimSpace(os.Getenv("MOHAWK_FEDAVG_ROUND_LABEL"))
	if roundLabel == "" {
		roundLabel = "r0"
	}

	if nodeCount < 1 {
		t.Fatalf("invalid MOHAWK_SWARM_NODE_COUNT: %d", nodeCount)
	}
	if maliciousRatio < 0 || maliciousRatio > 0.99 {
		t.Fatalf("invalid MOHAWK_SWARM_MALICIOUS_RATIO: %.4f", maliciousRatio)
	}
	if localEpochs < 1 {
		t.Fatalf("invalid MOHAWK_FEDAVG_LOCAL_EPOCHS: %d", localEpochs)
	}
	if participation <= 0 || participation > 1.0 {
		t.Fatalf("invalid MOHAWK_FEDAVG_PARTICIPATION: %.4f", participation)
	}

	activeNodes := int(float64(nodeCount) * participation)
	if activeNodes < 1 {
		activeNodes = 1
	}
	malicious := int(float64(activeNodes) * maliciousRatio)
	honest := activeNodes - malicious
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
	scenario := fedAvgScenarioFromEnv(localEpochs, participation)
	metrics.ObserveFedAvgModelAccuracy(scenario, "runtime-profile", roundLabel, estimateAccuracy(localEpochs, maliciousRatio))
	metrics.ObserveFedAvgModelLoss(scenario, "runtime-profile", roundLabel, estimateLoss(localEpochs, maliciousRatio))

	if expectFailure {
		if err == nil {
			t.Fatalf("expected failure for profile nodes=%d ratio=%.4f participation=%.2f epochs=%d, got success", nodeCount, maliciousRatio, participation, localEpochs)
		}
		return
	}

	if err != nil {
		t.Fatalf("expected success for profile nodes=%d ratio=%.4f participation=%.2f epochs=%d, got error=%v", nodeCount, maliciousRatio, participation, localEpochs, err)
	}
}

func fedAvgScenarioFromEnv(localEpochs int, participation float64) string {
	part := int(participation * 100)
	return fmt.Sprintf("fedavg_e%d_p%d", localEpochs, part)
}

func estimateAccuracy(localEpochs int, maliciousRatio float64) float64 {
	base := 90.0 + float64(localEpochs-1)*0.2
	penalty := maliciousRatio * 10.0
	acc := base - penalty
	if acc < 0 {
		return 0
	}
	if acc > 100 {
		return 100
	}
	return acc
}

func estimateLoss(localEpochs int, maliciousRatio float64) float64 {
	base := 0.25 - float64(localEpochs-1)*0.01
	if base < 0.05 {
		base = 0.05
	}
	return base + maliciousRatio*0.5
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
