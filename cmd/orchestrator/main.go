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
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

var orchPriv ed25519.PrivateKey
var orchPub ed25519.PublicKey

type NextJobResponse struct {
	Wasm []byte            `json:"wasm"`
	Man  manifest.Manifest `json:"manifest"`
}

func main() {
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	orchPriv = priv
	orchPub = priv.Public().(ed25519.PublicKey)

	workerCount := runtime.NumCPU() * 2
	StartAttestationWorkers(workerCount)

	_, _ = tpm.GetVerifiedQuote("orchestrator")

	meshDimensions := 1024
	if raw := os.Getenv("MOHAWK_MESH_DIMENSIONS"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			meshDimensions = parsed
		}
	}

	transportCfg := network.DefaultConfig(defaultPort(os.Getenv("MOHAWK_LIBP2P_PORT"), 4101))
	transportCfg.RelayAddrs = splitRelayAddrs(os.Getenv("MOHAWK_RELAY_ADDRS"))
	transportHost, err := network.NewHost(context.Background(), transportCfg)
	if err != nil {
		log.Fatalf("failed to initialize libp2p host: %v", err)
	}
	defer transportHost.Close()
	log.Printf("orchestrator libp2p peer %s listening on %v", transportHost.ID(), transportHost.Addrs())

	server := &Server{
		Checkpoints:    ipfs.NewBackend(os.Getenv("IPFS_API_ENDPOINT")),
		MeshDimensions: meshDimensions,
		PeerHost:       transportHost,
	}
	// Register the libp2p gradient-submission protocol so edge nodes can deliver
	// gradient updates directly over the encrypted p2p transport.
	network.RegisterGradientHandler(transportHost, func(msg *network.GradientMessage) *network.GradientAck {
		log.Printf("gradient received: node=%s task=%s round=%d len=%d",
			msg.NodeID, msg.TaskID, msg.Round, len(msg.Gradients))
		return &network.GradientAck{Accepted: true}
	})

	mux := http.NewServeMux()
	mux.HandleFunc("/orchestrator/pubkey", handlePubkey)
	mux.HandleFunc("/jobs/next", handleNextJob)
	mux.HandleFunc("/attest", server.HandleAttest)
	mux.HandleFunc("/checkpoints/put", server.HandleCheckpointPut)
	mux.HandleFunc("/checkpoints/get", server.HandleCheckpointGet)
	mux.HandleFunc("/mesh/plan", server.HandleMeshPlan)
	mux.HandleFunc("/p2p/info", server.HandleP2PInfo)
	mux.Handle("/metrics", promhttp.Handler())

	tlsConfig, err := tpm.ServerTLSConfig("orchestrator")
	if err != nil {
		log.Fatalf("failed to initialize mTLS: %v", err)
	}

	httpServer := &http.Server{
		Addr:      ":8080",
		Handler:   mux,
		TLSConfig: tlsConfig,
	}

	log.Println("orchestrator listening with mTLS on :8080")
	log.Fatal(httpServer.ListenAndServeTLS("", ""))
}

func handlePubkey(w http.ResponseWriter, r *http.Request) {
	_, _ = w.Write([]byte(hex.EncodeToString(orchPub)))
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
	_ = json.NewEncoder(w).Encode(resp)
}

func loadWasm() ([]byte, string, error) {
	path := "wasm-modules/fl_task/target/wasm32-unknown-unknown/release/fl_task.wasm"
	b, err := os.ReadFile(path)
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

func defaultPort(value string, fallback int) int {
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func splitRelayAddrs(value string) []string {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	addrs := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			addrs = append(addrs, trimmed)
		}
	}
	return addrs
}
