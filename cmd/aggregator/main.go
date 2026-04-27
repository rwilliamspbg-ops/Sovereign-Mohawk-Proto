package main

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

type Update struct {
	ID    string  `json:"id"`
	Value float64 `json:"value"`
}

const maxRequestBodyBytes int64 = 1 << 20

func authorizeRequest(r *http.Request) bool {
	expected := strings.TrimSpace(os.Getenv("AGGREGATOR_AUTH_TOKEN"))
	if expected == "" {
		return true
	}
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if len(auth) < 7 || !strings.EqualFold(auth[:7], "Bearer ") {
		return false
	}
	provided := strings.TrimSpace(auth[7:])
	return subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) == 1
}

func aggregateHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if !authorizeRequest(r) {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)

	var updates []Update
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := verifyFormalByzantineCheck(); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusFailedDependency)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":            "failed",
			"formal_check_pass": false,
			"message":           err.Error(),
		})
		return
	}

	fmt.Printf("Aggregating %d updates\n", len(updates))

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]any{"status": "success", "formal_check_pass": true}); err != nil {
		log.Printf("failed to encode: %v", err)
	}
}

func verifyFormalByzantineCheck() error {
	totalNodes, hasTotal, err := parseOptionalIntEnv("AGGREGATOR_TOTAL_NODES")
	if err != nil {
		return err
	}
	maliciousNodes, hasMalicious, err := parseOptionalIntEnv("AGGREGATOR_MALICIOUS_NODES")
	if err != nil {
		return err
	}
	if !hasTotal || !hasMalicious {
		return fmt.Errorf("AGGREGATOR_TOTAL_NODES and AGGREGATOR_MALICIOUS_NODES must both be set for formal checks")
	}
	_, checkErr := tpm.VerifyByzantineResilience(totalNodes, maliciousNodes)
	return checkErr
}

func parseOptionalIntEnv(key string) (int, bool, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return 0, false, nil
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return 0, true, fmt.Errorf("invalid %s=%q: %w", key, raw, err)
	}
	return v, true, nil
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/aggregate", aggregateHandler)
	server := &http.Server{
		Addr:              ":" + port,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	fmt.Printf("Aggregator service starting on port %s...\n", port)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
