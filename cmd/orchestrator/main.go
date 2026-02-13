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
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"runtime"
	"time"
	"crypto/sha256"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

var orchPriv ed25519.PrivateKey
var orchPub ed25519.PublicKey

type OrchestratorData struct {
	NodeID string            `json:"node_id"`
	Man    manifest.Manifest `json:"manifest"`
}

type NextJobResponse struct {
	Wasm []byte            `json:"wasm"`
	Man  manifest.Manifest `json:"manifest"`
}

func main() {
	// Initialize keys
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	orchPriv = priv
	orchPub = priv.Public().(ed25519.PublicKey)

	// Start Workers
	workerCount := runtime.NumCPU() * 2
	StartAttestationWorkers(workerCount)

	// Satisfy linter for internal/tpm
	_ = tpm.Verify("init-check", []byte{})

	http.HandleFunc("/orchestrator/pubkey", handlePubkey)
	http.HandleFunc("/jobs/next", handleNextJob)
	http.HandleFunc("/attest", (&Server{}).HandleAttest)

	log.Println("orchestrator listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handlePubkey(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(hex.EncodeToString(orchPub)))
}

func handleNextJob(w http.ResponseWriter, r *http.Request) {
	nodeID := r.URL.Query().Get("node_id")
	if nodeID == "" {
		http.Error(w, "node_id required", http.StatusBadRequest)
		return
	}

	wasmBytes, wasmHash, err := loadWasm()
	if err != nil {
		http.Error(w, "no wasm", http.StatusInternalServerError)
		return
	}

	m := manifest.Manifest{
		TaskID:           "task-" + time.Now().Format("150405"),
		NodeID:           nodeID,
		WasmModuleSHA256: wasmHash,
		Capabilities: []manifest.Capability{
			manifest.CapLog,
			manifest.CapSubmitGrad,
		},
		MaxMemPages: 64,
		MaxMillis:   30000,
		Epsilon:     2.0,
	}

	signManifest(&m)
	resp := NextJobResponse{Wasm: wasmBytes, Man: m}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func loadWasm() ([]byte, string, error) {
	// Build the module into wasm-modules/fl_task/target/wasm32-unknown-unknown/release/fl_task.wasm
	path := "wasm-modules/fl_task/target/wasm32-unknown-unknown/release/fl_task.wasm"
	b, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, "", err
	}
	sum := sha256.Sum256(b)
	return b, hex.EncodeToString(sum[:]), nil
}

func signManifest(m *manifest.Manifest) {
	data, _ := json.Marshal(m)
	sig := ed25519.Sign(orchPriv, data)
	m.Signature = sig
}

func loadWasm() ([]byte, string, error) {
	// Build the module into wasm-modules/fl_task/target/wasm32-unknown-unknown/release/fl_task.wasm
	path := "wasm-modules/fl_task/target/wasm32-unknown-unknown/release/fl_task.wasm"
	b, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, "", err
	}
	sum := sha256.Sum256(b)
	return b, hex.EncodeToString(sum[:]), nil
}

func signManifest(m *manifest.Manifest) {
	m.Signature = nil
	data, _ := json.Marshal(m)
	sig := ed25519.Sign(orchPriv, data)
	m.Signature = sig
}
