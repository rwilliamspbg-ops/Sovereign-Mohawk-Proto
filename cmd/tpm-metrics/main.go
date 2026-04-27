package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	dto "github.com/prometheus/client_model/go"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

type prefixFilteringGatherer struct {
	delegate        prometheus.Gatherer
	allowedPrefixes []string
}

func (g prefixFilteringGatherer) Gather() ([]*dto.MetricFamily, error) {
	families, err := g.delegate.Gather()
	if err != nil {
		return nil, err
	}
	filtered := make([]*dto.MetricFamily, 0, len(families))
	for _, family := range families {
		name := family.GetName()
		for _, prefix := range g.allowedPrefixes {
			if len(name) >= len(prefix) && name[:len(prefix)] == prefix {
				filtered = append(filtered, family)
				break
			}
		}
	}
	return filtered, nil
}

func main() {
	addr := os.Getenv("TPM_METRICS_ADDR")
	if addr == "" {
		addr = ":9102"
	}

	gatherer := prefixFilteringGatherer{
		delegate: prometheus.DefaultGatherer,
		allowedPrefixes: []string{
			"go_",
			"process_",
			"promhttp_",
			"mohawk_tpm_",
		},
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.HandlerFor(gatherer, promhttp.HandlerOpts{}))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":                     "ok",
			"attestation_signature_mode": tpm.ActiveAttestationSignatureMode(),
		})
	})

	log.Printf("TPM metrics exporter listening on %s", addr)
	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Fatal(server.ListenAndServe())
}
