package main

import (
	"encoding/json"
	"io"
	"log"
	"math"
	"net/http"
)

type GradPayload struct {
	NodeID string    `json:"node_id"`
	Grads  []float64 `json:"grads"`
}

func main() {
	http.HandleFunc("/fl/submit", handleSubmit)
	log.Println("FL aggregator on :8090")
	log.Fatal(http.ListenAndServe(":8090", nil))
}

func handleSubmit(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
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

