// Command federation-demo runs one node of a two-level aggregation demo.
//
// Serve mode starts a federation coordinator and exposes /stats on
// FED_DEMO_STATS_ADDR (default :9130). Inject mode sends synthetic child
// gradients to FED_DEMO_PARENT over the project's federation RPC protocol.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/federation"
)

func envDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) int {
	value, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key)))
	if err != nil {
		return fallback
	}
	return value
}

func tierLevelFromName(name string) federation.TierLevel {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "global":
		return federation.TierGlobal
	case "continental":
		return federation.TierContinental
	default:
		return federation.TierRegional
	}
}

func buildConfig() federation.TierConfig {
	return federation.TierConfig{
		TierID:                 envDefault("FED_DEMO_TIER", "regional-1"),
		Level:                  tierLevelFromName(envDefault("FED_DEMO_LEVEL", "regional")),
		ParentTierNodeID:       envDefault("FED_DEMO_PARENT_ID", "global-1"),
		ChildNodeIDs:           strings.Split(envDefault("FED_DEMO_CHILDREN", "child-1,child-2,child-3"), ","),
		MinQuorumSize:          envInt("FED_DEMO_MIN_QUORUM", 3),
		AggregationTimeoutMs:   envInt("FED_DEMO_TIMEOUT_MS", 1000),
		ByzantineToleranceFrac: 0.33,
		MaxBufferedGradients:   1000,
		AsyncMode:              strings.EqualFold(envDefault("FED_DEMO_ASYNC", "false"), "true"),
		StalenessWindow:        3,
	}
}

func inject(ctx context.Context, config federation.TierConfig, parent string) {
	client := federation.NewRPCClient(config, parent)
	defer client.Close()
	count := envInt("FED_DEMO_COUNT", 6)
	interval := time.Duration(envInt("FED_DEMO_INTERVAL_MS", 500)) * time.Millisecond
	for i := 1; i <= count; i++ {
		select {
		case <-ctx.Done():
			return
		default:
		}
		vector := make([]float64, 8)
		for j := range vector {
			vector[j] = float64(i+j) / 10.0
		}
		msg := &federation.GradientMessage{
			GradientID:       fmt.Sprintf("%s-r%d-g%d", config.TierID, i, i),
			SourceNodeID:     fmt.Sprintf("%s-child-%d", config.TierID, i),
			SourceTierNodeID: config.TierID,
			AggregationRound: uint64(i),
			DimensionCount:   len(vector),
			GradientData:     vector,
			Norm:             1.0,
			Timestamp:        time.Now().UTC(),
		}
		if err := client.ForwardGradient(ctx, msg); err != nil {
			log.Printf("[%s demo] inject %d failed: %v", config.TierID, i, err)
		} else {
			log.Printf("[%s demo] injected round %d into %s", config.TierID, i, parent)
		}
		time.Sleep(interval)
	}
}

func main() {
	config := buildConfig()
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	mode := envDefault("FED_DEMO_MODE", "serve")
	parent := envDefault("FED_DEMO_PARENT", "")
	if mode == "inject" {
		if parent == "" {
			log.Fatal("FED_DEMO_PARENT is required in inject mode")
		}
		inject(ctx, config, parent)
		return
	}

	listen := envDefault("FED_DEMO_LISTEN", ":9125")
	coordinator, err := federation.NewCoordinator(config, listen, parent)
	if err != nil {
		log.Fatalf("create coordinator: %v", err)
	}
	if err := coordinator.Start(ctx, listen); err != nil {
		log.Fatalf("start coordinator: %v", err)
	}
	defer coordinator.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/stats", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(coordinator.Stats())
	})
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	statsAddr := envDefault("FED_DEMO_STATS_ADDR", ":9130")
	log.Printf("[%s demo] tier=%s listening=%s parent=%s stats=%s", config.TierID, envDefault("FED_DEMO_LEVEL", "regional"), listen, parent, statsAddr)
	log.Fatal(http.ListenAndServe(statsAddr, mux))
}
