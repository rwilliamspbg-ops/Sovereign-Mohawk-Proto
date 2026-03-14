/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package main

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
)

// Server handles orchestrator HTTP requests.
type Server struct {
	Checkpoints    *ipfs.Backend
	MeshDimensions int
	PeerHost       corehost.Host
}

// HandleP2PInfo returns this orchestrator's libp2p peer ID and listen addresses.
// Node-agents use this to dial the orchestrator directly over the gradient protocol.
func (s *Server) HandleP2PInfo(w http.ResponseWriter, r *http.Request) {
	if s.PeerHost == nil {
		http.Error(w, "libp2p host not initialized", http.StatusServiceUnavailable)
		return
	}
	addrs := make([]string, 0, len(s.PeerHost.Addrs()))
	for _, a := range s.PeerHost.Addrs() {
		addrs = append(addrs, a.String())
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"peer_id": s.PeerHost.ID().String(),
		"addrs":   addrs,
	})
}

type AttestationJob struct {
	NodeID string
	Quote  []byte
	Resp   chan error
}

var JobQueue = make(chan AttestationJob, 100)

func (s *Server) HandleAttest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		NodeID string `json:"node_id"`
		Quote  []byte `json:"quote"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	respChan := make(chan error)
	JobQueue <- AttestationJob{
		NodeID: req.NodeID,
		Quote:  req.Quote,
		Resp:   respChan,
	}

	if err := <-respChan; err != nil {
		http.Error(w, "attestation failed", http.StatusForbidden)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) HandleCheckpointPut(w http.ResponseWriter, r *http.Request) {
	if s.Checkpoints == nil || !s.Checkpoints.Enabled() {
		http.Error(w, "ipfs backend not configured", http.StatusServiceUnavailable)
		return
	}

	var req struct {
		Name    string `json:"name"`
		Payload string `json:"payload"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	cid, err := s.Checkpoints.PutCheckpoint(ctx, req.Name, []byte(req.Payload))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]string{"cid": cid})
}

func (s *Server) HandleCheckpointGet(w http.ResponseWriter, r *http.Request) {
	if s.Checkpoints == nil || !s.Checkpoints.Enabled() {
		http.Error(w, "ipfs backend not configured", http.StatusServiceUnavailable)
		return
	}

	cid := r.URL.Query().Get("cid")
	if cid == "" {
		http.Error(w, "cid required", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	payload, err := s.Checkpoints.GetCheckpoint(ctx, cid)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]string{"payload": string(payload)})
}

func (s *Server) HandleMeshPlan(w http.ResponseWriter, r *http.Request) {
	totalNodes, err := strconv.Atoi(defaultString(r.URL.Query().Get("total_nodes"), "10000000"))
	if err != nil {
		http.Error(w, "invalid total_nodes", http.StatusBadRequest)
		return
	}
	dimensions, err := strconv.Atoi(defaultString(r.URL.Query().Get("dimensions"), strconv.Itoa(s.MeshDimensions)))
	if err != nil {
		http.Error(w, "invalid dimensions", http.StatusBadRequest)
		return
	}
	plan, err := hva.BuildPlan(totalNodes, dimensions)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	_ = json.NewEncoder(w).Encode(plan)
}

func defaultString(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
