package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

func main() {
	addr := os.Getenv("TPM_METRICS_ADDR")
	if addr == "" {
		addr = ":9102"
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":                     "ok",
			"attestation_signature_mode": tpm.ActiveAttestationSignatureMode(),
		})
	})

	log.Printf("TPM metrics exporter listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
