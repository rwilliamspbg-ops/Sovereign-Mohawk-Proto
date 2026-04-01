package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
)

func main() {
	port := envInt("MOHAWK_PYAPI_EXPORTER_PORT", 9104)
	interval := time.Duration(envInt("MOHAWK_PYAPI_TRAFFIC_INTERVAL_SECONDS", 10)) * time.Second
	if interval < 2*time.Second {
		interval = 2 * time.Second
	}

	go emitSyntheticBridgeAndHybrid(interval)

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"ok": true, "interval_seconds": int(interval.Seconds())})
	})

	addr := ":" + strconv.Itoa(port)
	log.Printf("pyapi metrics exporter listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func emitSyntheticBridgeAndHybrid(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		bridgeStart := time.Now()
		bridgeLatency := float64(time.Since(bridgeStart).Microseconds()) / 1000.0
		metrics.ObserveBridgeTransfer("ethereum", "polygon", true)
		metrics.ObserveBridgeTransferLatency("ethereum", "polygon", true, bridgeLatency)
		metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", true)
		metrics.ObserveAcceleratorOpLatency("cpu", "bridge_transfer", bridgeLatency)

		hybridStart := time.Now()
		hybridLatency := float64(time.Since(hybridStart).Microseconds()) / 1000.0
		metrics.ObserveProofVerification("hybrid", false, hybridLatency)
		metrics.ObserveAcceleratorOp("cpu", "hybrid_verify", false)
		metrics.ObserveAcceleratorOpLatency("cpu", "hybrid_verify", hybridLatency)

		compressionStart := time.Now()
		compressionLatency := float64(time.Since(compressionStart).Microseconds()) / 1000.0
		metrics.ObserveGradientCompression("int8", 2.25)
		metrics.ObserveAcceleratorOp("cpu", "compress_int8", true)
		metrics.ObserveAcceleratorOpLatency("cpu", "compress_int8", compressionLatency)

		<-ticker.C
	}
}

func envInt(name string, fallback int) int {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}
