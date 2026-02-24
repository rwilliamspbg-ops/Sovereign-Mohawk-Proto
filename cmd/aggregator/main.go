package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

type Update struct {
	ID    string  `json:"id"`
	Value float64 `json:"value"`
}

func aggregateHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

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
