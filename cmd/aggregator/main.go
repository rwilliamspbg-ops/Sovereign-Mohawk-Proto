// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"log"
	"net/http"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func main() {
	log.Println("Global Aggregator starting...")

	// 1. Initialize the Global Tier Aggregator (Theorem 3)
	// This tier coordinates the continental sub-trees.
	agg := internal.NewAggregator(internal.Global)

	// 2. Setup Health and Monitoring
	// In a production 10M-node scenario, this would interface with
	// the Prometheus/Grafana stack for real-time BFT metrics.
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("Sovereign-Mohawk Aggregator: Online"))
	})

	// 3. Simulation: Process initial synchronization
	// We simulate a 1,000-region active set to verify the
	// 99.99% success probability (Theorem 4).
	activeNodes := 999
	totalNodes := 1000
	gradNorm := 0.05 // Typical convergence value

	log.Printf("Verifying initial synchronization for %d nodes...", activeNodes)

	if err := agg.ProcessUpdates(activeNodes, totalNodes, gradNorm); err != nil {
		log.Fatalf("Critical Safety Guard Triggered: %v", err)
	}

	server := &http.Server{
		Addr:         ":8080",
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Println("Aggregator listening on :8080")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Aggregator failed: %v", err)
	}
}
