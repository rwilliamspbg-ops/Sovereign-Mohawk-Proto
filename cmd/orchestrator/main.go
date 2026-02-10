// cmd/orchestrator/main.go
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"sovereign/internal/manifest"
)

var orchPriv ed25519.PrivateKey
var orchPub ed25519.PublicKey

func main() {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	orchPriv = priv
	orchPub = priv.Public().(ed25519.PublicKey)

	http.HandleFunc("/orchestrator/pubkey", handlePubkey)
	http.HandleFunc("/jobs/next", handleNextJob)

	log.Println("orchestrator listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handlePubkey(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(hex.EncodeToString(orchPub)))
}

type NextJobResponse struct {
	Wasm []byte             `json:"wasm"` // base64 if you prefer
	Man  manifest.Manifest  `json:"manifest"`
}

func handleNextJob(w http.ResponseWriter, r *http.Request) {
	nodeID := r.URL.Query().Get("node_id")
	if nodeID == "" {
		http.Error(w, "node_id required", http.StatusBadRequest)
		return
	}

	wasmBytes, wasmHash := loadWasm() // read from disk, compute sha256

	m := manifest.Manifest{
		TaskID:           "task-" + time.Now().Format("150405"),
		NodeID:           nodeID,
		WasmModuleSHA256: wasmHash,
		Capabilities: []manifest.Capability{
			manifest.CapLog,
			manifest.CapSubmitGrad,
		},
		MaxMemPages: 64,
		MaxMillis:   30_000,
		MaxGradNorm: 10.0,
		Epsilon:     2.0,
		Delta:       1e-5,
	}

	signManifest(&m)

	resp := NextJobResponse{Wasm: wasmBytes, Man: m}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func signManifest(m *manifest.Manifest) {
	m.Signature = nil
	data, _ := json.Marshal(m)
	sig := ed25519.Sign(orchPriv, data)
	m.Signature = sig
}

// implement loadWasm() + sha256 helper
