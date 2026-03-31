package main

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
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

	fmt.Printf("Aggregating %d updates\n", len(updates))

	w.Header().Set("Content-Type", "application/json")
	// Satisfy linter with error check
	if err := json.NewEncoder(w).Encode(map[string]string{"status": "success"}); err != nil {
		log.Printf("failed to encode: %v", err)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/aggregate", aggregateHandler)

	fmt.Printf("Aggregator service starting on port %s...\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
