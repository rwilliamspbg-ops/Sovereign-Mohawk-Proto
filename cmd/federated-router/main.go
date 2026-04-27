package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/proofs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/router"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

func main() {
	r, err := newRouterFromEnv()
	if err != nil {
		log.Fatalf("failed to initialize router: %v", err)
	}

	mux := buildMux(r)
	wrappedMux := withPanicRecovery(mux)

	// Start /metrics on configurable address; default remains loopback for safety.
	go func() {
		metricsAddr := defaultString(os.Getenv("MOHAWK_ROUTER_METRICS_ADDR"), "127.0.0.1:8088")
		metricsMux := http.NewServeMux()
		metricsMux.Handle("/metrics", promhttp.Handler())
		metricsServer := &http.Server{
			Addr:              metricsAddr,
			Handler:           metricsMux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      15 * time.Second,
			IdleTimeout:       60 * time.Second,
		}
		log.Printf("metrics endpoint listening on %s", metricsAddr)
		if err := metricsServer.ListenAndServe(); err != nil {
			log.Printf("metrics server failed: %v", err)
		}
	}()

	addr := defaultString(os.Getenv("MOHAWK_ROUTER_ADDR"), ":8087")
	server := &http.Server{
		Addr:              addr,
		Handler:           wrappedMux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("federated router listening on %s", addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("router server failed: %v", err)
	}
}

func newRouterFromEnv() (*router.Router, error) {
	policy := router.NewPolicyEngine()
	routes := parseRoutes(os.Getenv("MOHAWK_ROUTER_ALLOWED_ROUTES"))
	policy.LoadRoutes(routes)
	if len(routes) == 0 {
		policy.Allow("climate", "agriculture")
		policy.Allow("climate", "supply-chain")
		policy.Allow("oncology", "supply-chain")
	}
	var ledger *router.ProvenanceLedger
	persistPath := strings.TrimSpace(os.Getenv("MOHAWK_ROUTER_PROVENANCE_PATH"))
	if persistPath != "" {
		fileBacked, err := router.NewFileBackedProvenanceLedger(persistPath)
		if err != nil {
			return nil, err
		}
		ledger = fileBacked
	} else {
		ledger = router.NewProvenanceLedger()
	}

	allowInsecureQuotes := parseBoolEnv(os.Getenv("MOHAWK_ROUTER_ALLOW_INSECURE_DEV_QUOTES"))
	quoteVerifier := func(nodeID string, quote []byte) error {
		if allowInsecureQuotes {
			return nil
		}
		return tpm.Verify(nodeID, quote)
	}

	r := router.NewWithLedger(
		policy,
		quoteVerifier,
		func(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
			return proofs.VerifyZKProof(expectedRoot, proofData, salt)
		},
		ledger,
	)
	metrics.ObserveRouterProvenanceRecords(len(r.Provenance()))
	return r, nil
}

func buildMux(r *router.Router) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, req *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/router/publish", publishHandler(r))
	mux.HandleFunc("/router/subscribe", subscribeHandler(r))
	mux.HandleFunc("/router/discover", discoverHandler(r))
	mux.HandleFunc("/router/provenance", provenanceHandler(r))
	// Remove /metrics from public mux
	return mux
}

// Panic recovery middleware
func withPanicRecovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("panic: %v", rec)
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func publishHandler(r *router.Router) http.HandlerFunc {
	return rateLimitMiddleware(func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodPost {
			metrics.ObserveRouterRequest("publish", false, "method_not_allowed")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var offer router.InsightOffer
		if err := json.NewDecoder(req.Body).Decode(&offer); err != nil {
			metrics.ObserveRouterRequest("publish", false, "invalid_json")
			http.Error(w, "invalid request", http.StatusBadRequest)
			log.Printf("publish decode error: %v", err)
			return
		}
		// Input validation
		if offer.SourceVertical == "" || offer.ModelID == "" || offer.PublisherNodeID == "" || len(offer.PublisherQuote) == 0 {
			metrics.ObserveRouterRequest("publish", false, "validation")
			http.Error(w, "invalid request", http.StatusBadRequest)
			log.Printf("publish validation failed: %+v", offer)
			return
		}
		published, err := r.PublishInsight(offer)
		if err != nil {
			metrics.ObserveRouterRequest("publish", false, classifyRouterError(err))
			http.Error(w, "request failed", http.StatusBadRequest)
			log.Printf("publish error: %v", err)
			return
		}
		metrics.ObserveRouterRequest("publish", true, "none")
		_ = json.NewEncoder(w).Encode(published)
	})
}

func subscribeHandler(r *router.Router) http.HandlerFunc {
	return rateLimitMiddleware(func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodPost {
			metrics.ObserveRouterRequest("subscribe", false, "method_not_allowed")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var sub router.SubscriptionRequest
		if err := json.NewDecoder(req.Body).Decode(&sub); err != nil {
			metrics.ObserveRouterRequest("subscribe", false, "invalid_json")
			http.Error(w, "invalid request", http.StatusBadRequest)
			log.Printf("subscribe decode error: %v", err)
			return
		}
		// Input validation
		if sub.SubscriberVertical == "" || len(sub.SourceVerticals) == 0 || sub.SubscriberNodeID == "" || len(sub.SubscriberQuote) == 0 {
			metrics.ObserveRouterRequest("subscribe", false, "validation")
			http.Error(w, "invalid request", http.StatusBadRequest)
			log.Printf("subscribe validation failed: %+v", sub)
			return
		}
		if err := r.RegisterSubscription(sub); err != nil {
			metrics.ObserveRouterRequest("subscribe", false, classifyRouterError(err))
			http.Error(w, "request failed", http.StatusBadRequest)
			log.Printf("subscribe error: %v", err)
			return
		}
		metrics.ObserveRouterRequest("subscribe", true, "none")
		w.WriteHeader(http.StatusNoContent)
	})
}

func discoverHandler(r *router.Router) http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		if req.Method != http.MethodGet {
			metrics.ObserveRouterRequest("discover", false, "method_not_allowed")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		subscriber := req.URL.Query().Get("subscriber_vertical")
		offers, err := r.Discover(subscriber)
		if err != nil {
			metrics.ObserveRouterRequest("discover", false, classifyRouterError(err))
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		metrics.ObserveRouterRequest("discover", true, "none")
		_ = json.NewEncoder(w).Encode(offers)
	}
}

func provenanceHandler(r *router.Router) http.HandlerFunc {
	return rateLimitMiddleware(func(w http.ResponseWriter, req *http.Request) {
		switch req.Method {
		case http.MethodGet:
			records := r.Provenance()
			metrics.ObserveRouterRequest("provenance_get", true, "none")
			metrics.ObserveRouterProvenanceRecords(len(records))
			_ = json.NewEncoder(w).Encode(records)
		case http.MethodPost:
			var event router.ProvenanceEvent
			if err := json.NewDecoder(req.Body).Decode(&event); err != nil {
				metrics.ObserveRouterRequest("provenance_post", false, "invalid_json")
				http.Error(w, "invalid request", http.StatusBadRequest)
				log.Printf("provenance decode error: %v", err)
				return
			}
			// Input validation
			if event.OfferID == "" || event.SourceVertical == "" || event.TargetVertical == "" || event.SubscriberModel == "" {
				metrics.ObserveRouterRequest("provenance_post", false, "validation")
				http.Error(w, "invalid request", http.StatusBadRequest)
				log.Printf("provenance validation failed: %+v", event)
				return
			}
			record, err := r.RecordTransfer(event)
			if err != nil {
				metrics.ObserveRouterRequest("provenance_post", false, classifyRouterError(err))
				http.Error(w, "request failed", http.StatusBadRequest)
				log.Printf("provenance error: %v", err)
				return
			}
			metrics.ObserveRouterRequest("provenance_post", true, "none")
			metrics.ObserveRouterProvenanceRecords(len(r.Provenance()))
			_ = json.NewEncoder(w).Encode(record)
		default:
			metrics.ObserveRouterRequest("provenance", false, "method_not_allowed")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
}

// Simple in-memory rate limiter (per IP, bursty, not production-grade)
var rateLimiters = make(map[string]int)
var rateLimiterMu sync.Mutex

func rateLimitMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		rateLimiterMu.Lock()
		count := rateLimiters[ip]
		if count > 20 {
			rateLimiterMu.Unlock()
			http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
			return
		}
		rateLimiters[ip] = count + 1
		rateLimiterMu.Unlock()
		next(w, r)
	}
}

func classifyRouterError(err error) string {
	if err == nil {
		return "none"
	}
	message := strings.ToLower(err.Error())
	switch {
	case strings.Contains(message, "proof verification failed"):
		return "proof_verification"
	case strings.Contains(message, "attestation failed"):
		return "forged_quote_or_attestation"
	case strings.Contains(message, "is blocked"):
		return "route_blocked"
	case strings.Contains(message, "not allowed"):
		return "policy_rejected"
	case strings.Contains(message, "required"):
		return "validation"
	default:
		return "router_error"
	}
}

func parseBoolEnv(raw string) bool {
	v := strings.ToLower(strings.TrimSpace(raw))
	return v == "1" || v == "true" || v == "yes" || v == "on"
}

func ensureWriteJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(value); err != nil {
		http.Error(w, fmt.Sprintf("encode response: %v", err), http.StatusInternalServerError)
	}
}

func parseRoutes(raw string) map[string][]string {
	routes := map[string][]string{}
	for _, pair := range strings.Split(raw, ",") {
		parts := strings.Split(strings.TrimSpace(pair), "->")
		if len(parts) != 2 {
			continue
		}
		source := strings.TrimSpace(parts[0])
		target := strings.TrimSpace(parts[1])
		if source == "" || target == "" {
			continue
		}
		routes[source] = append(routes[source], target)
	}
	return routes
}

func defaultString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}
