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
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

// Server handles orchestrator HTTP requests.
type Server struct {
	Checkpoints      *ipfs.Backend
	MeshDimensions   int
	PeerHost         corehost.Host
	TransportKEXMode network.KEXMode
	UtilityLedger    *token.Ledger
	AdminToken       string
}

// HandleMigrationDigest returns the canonical migration digest to be signed by legacy and PQC keys.
func (s *Server) HandleMigrationDigest(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	success := false
	defer func() {
		metrics.ObserveMigrationRequest("digest", success, float64(time.Since(started).Microseconds())/1000.0)
	}()
	if !s.authorizeAdmin(w, r) {
		return
	}
	if s.UtilityLedger == nil {
		http.Error(w, "utility ledger not configured", http.StatusServiceUnavailable)
		return
	}
	var req struct {
		LegacyAccount  string  `json:"legacy_account"`
		PQCAccount     string  `json:"pqc_account"`
		Amount         float64 `json:"amount"`
		Memo           string  `json:"memo,omitempty"`
		IdempotencyKey string  `json:"idempotency_key,omitempty"`
		Nonce          uint64  `json:"nonce,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	amountUnits, err := s.UtilityLedger.AmountToUnits(req.Amount)
	if err != nil {
		http.Error(w, fmt.Sprintf("invalid amount: %v", err), http.StatusBadRequest)
		return
	}
	digest, err := token.MigrationSigningDigest(
		s.UtilityLedger.Symbol(),
		req.LegacyAccount,
		req.PQCAccount,
		amountUnits,
		req.Memo,
		req.IdempotencyKey,
		req.Nonce,
	)
	if err != nil {
		http.Error(w, fmt.Sprintf("digest failed: %v", err), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"symbol":       s.UtilityLedger.Symbol(),
		"amount_units": amountUnits,
		"digest_hex":   hex.EncodeToString(digest),
	})
	success = true
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
		"peer_id":                   s.PeerHost.ID().String(),
		"addrs":                     addrs,
		"kex_mode":                  s.TransportKEXMode,
		"expected_public_key_bytes": s.TransportKEXMode.ExpectedPublicKeyBytes(),
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

// HandleMigrationStatus returns the current PQC migration controls for the utility ledger.
func (s *Server) HandleMigrationStatus(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	success := false
	defer func() {
		metrics.ObserveMigrationRequest("status", success, float64(time.Since(started).Microseconds())/1000.0)
	}()
	if s.UtilityLedger == nil {
		http.Error(w, "utility ledger not configured", http.StatusServiceUnavailable)
		return
	}
	status := s.UtilityLedger.PQCMigrationStatus()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(status)
	success = true
}

// HandleMigrationConfig updates migration window controls.
func (s *Server) HandleMigrationConfig(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	success := false
	defer func() {
		metrics.ObserveMigrationRequest("config", success, float64(time.Since(started).Microseconds())/1000.0)
	}()
	if !s.authorizeAdmin(w, r) {
		return
	}
	if s.UtilityLedger == nil {
		http.Error(w, "utility ledger not configured", http.StatusServiceUnavailable)
		return
	}
	var req struct {
		Enabled             bool   `json:"enabled"`
		MigrationETA        string `json:"migration_eta,omitempty"`
		MigrationEpoch      string `json:"migration_epoch,omitempty"`
		RequireCryptoEpoch  bool   `json:"require_crypto_epoch"`
		LockLegacyTransfers bool   `json:"lock_legacy_transfers"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	var eta time.Time
	if strings.TrimSpace(req.MigrationETA) != "" {
		parsed, err := time.Parse(time.RFC3339, req.MigrationETA)
		if err != nil {
			http.Error(w, "migration_eta must be RFC3339", http.StatusBadRequest)
			return
		}
		eta = parsed
	}
	var epoch time.Time
	if strings.TrimSpace(req.MigrationEpoch) != "" {
		parsed, err := time.Parse(time.RFC3339, req.MigrationEpoch)
		if err != nil {
			http.Error(w, "migration_epoch must be RFC3339", http.StatusBadRequest)
			return
		}
		epoch = parsed
	}
	s.UtilityLedger.ConfigurePQCMigration(req.Enabled, eta, req.LockLegacyTransfers)
	s.UtilityLedger.ConfigurePQCMigrationEpoch(epoch, req.RequireCryptoEpoch)
	metrics.ObservePQCPolicyEnabled("migration_enabled", req.Enabled)
	metrics.ObservePQCPolicyEnabled("migration_lock_legacy_transfers", req.LockLegacyTransfers)
	metrics.ObservePQCPolicyEnabled("require_crypto_after_epoch", req.RequireCryptoEpoch)
	if !epoch.IsZero() {
		metrics.ObservePQCEpochUnix("migration_epoch", epoch.Unix())
	}
	if !eta.IsZero() {
		metrics.ObservePQCEpochUnix("migration_eta", eta.Unix())
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(s.UtilityLedger.PQCMigrationStatus())
	success = true
}

// HandleMigrationTransfer performs a dual-signature migration transfer from legacy to PQC account.
func (s *Server) HandleMigrationTransfer(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	success := false
	signaturePath := "legacy_controls"
	defer func() {
		metrics.ObserveMigrationRequest("migrate", success, float64(time.Since(started).Microseconds())/1000.0)
		metrics.ObserveMigrationSignaturePath(signaturePath, success)
	}()
	if !s.authorizeAdmin(w, r) {
		return
	}
	if s.UtilityLedger == nil {
		http.Error(w, "utility ledger not configured", http.StatusServiceUnavailable)
		return
	}
	var req struct {
		LegacyAccount  string  `json:"legacy_account"`
		PQCAccount     string  `json:"pqc_account"`
		Amount         float64 `json:"amount"`
		Memo           string  `json:"memo,omitempty"`
		LegacySigned   bool    `json:"legacy_signed"`
		PQCSigned      bool    `json:"pqc_signed"`
		LegacyAlgo     string  `json:"legacy_algo,omitempty"`
		LegacyPubKey   string  `json:"legacy_pub_key,omitempty"`
		LegacySig      string  `json:"legacy_sig,omitempty"`
		PQCAlgo        string  `json:"pqc_algo,omitempty"`
		PQCPubKey      string  `json:"pqc_pub_key,omitempty"`
		PQCSig         string  `json:"pqc_sig,omitempty"`
		IdempotencyKey string  `json:"idempotency_key,omitempty"`
		Nonce          uint64  `json:"nonce,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	signatures := token.MigrationSignatureBundle{
		LegacyAlgorithm: req.LegacyAlgo,
		LegacyPublicKey: req.LegacyPubKey,
		LegacySignature: req.LegacySig,
		PQCAlgorithm:    req.PQCAlgo,
		PQCPublicKey:    req.PQCPubKey,
		PQCSignature:    req.PQCSig,
	}
	var tx token.Tx
	var err error
	if signatures.Enabled() {
		signaturePath = "dual_crypto"
		tx, err = s.UtilityLedger.MigrateWithDualSignatureCryptographic(
			req.LegacyAccount,
			req.PQCAccount,
			req.Amount,
			req.Memo,
			signatures,
			req.IdempotencyKey,
			req.Nonce,
		)
	} else {
		tx, err = s.UtilityLedger.MigrateWithDualSignatureControls(
			req.LegacyAccount,
			req.PQCAccount,
			req.Amount,
			req.Memo,
			req.LegacySigned,
			req.PQCSigned,
			req.IdempotencyKey,
			req.Nonce,
		)
	}
	if err != nil {
		http.Error(w, fmt.Sprintf("migration failed: %v", err), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"tx": tx})
	success = true
}

func (s *Server) authorizeAdmin(w http.ResponseWriter, r *http.Request) bool {
	expected := strings.TrimSpace(s.AdminToken)
	if expected == "" {
		return true
	}
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if auth != "Bearer "+expected {
		metrics.ObserveAuthzDenial(strings.TrimSpace(r.URL.Path), "invalid_bearer_token")
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return false
	}
	return true
}

func defaultString(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
