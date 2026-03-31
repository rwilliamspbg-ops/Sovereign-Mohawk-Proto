// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package main

import (
	"crypto/subtle"
	"encoding/json"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"strings"
)

type GradPayload struct {
	NodeID string    `json:"node_id"`
	Grads  []float64 `json:"grads"`
}

const maxRequestBodyBytes int64 = 1 << 20

func authorizeRequest(r *http.Request) bool {
	expected := strings.TrimSpace(os.Getenv("FL_AGGREGATOR_AUTH_TOKEN"))
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

func main() {
	http.HandleFunc("/fl/submit", handleSubmit)
	log.Println("FL aggregator on :8090")
	log.Fatal(http.ListenAndServe(":8090", nil))
}

func handleSubmit(w http.ResponseWriter, r *http.Request) {
	if !authorizeRequest(r) {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read request body", http.StatusBadRequest)
		return
	}
	var p GradPayload
	if err := json.Unmarshal(body, &p); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}

	maxNorm := 10.0
	norm := 0.0
	for _, g := range p.Grads {
		norm += g * g
	}
	norm = math.Sqrt(norm)
	if norm > maxNorm {
		scale := maxNorm / norm
		for i := range p.Grads {
			p.Grads[i] *= scale
		}
	}

	log.Printf("received %d grads from %s (clipped)", len(p.Grads), p.NodeID)
	w.WriteHeader(http.StatusOK)
}
