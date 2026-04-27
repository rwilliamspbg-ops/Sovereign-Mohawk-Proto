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
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/manifest"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/startup"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
)

var orchPriv ed25519.PrivateKey
var orchPub ed25519.PublicKey

var buildVersion = "dev"
var buildCommit = "unknown"
var buildDate = "unknown"

type NextJobResponse struct {
	Wasm []byte            `json:"wasm"`
	Man  manifest.Manifest `json:"manifest"`
}

func main() {
	startup.LogRuntimeMetadata("orchestrator", buildVersion, buildCommit, buildDate)
	if err := startup.EnforceFIPSGate("orchestrator"); err != nil {
		log.Fatal(err)
	}

	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		log.Fatal(err)
	}
	orchPriv = priv
	orchPub = priv.Public().(ed25519.PublicKey)

	tune := accelerator.BuildAutoTuneProfile(0)
	if tune.RecommendedWorker > 0 {
		runtime.GOMAXPROCS(tune.RecommendedWorker)
	}
	workerCount := runtime.GOMAXPROCS(0)
	log.Printf("orchestrator autotune selected backend=%s workers=%d", tune.SelectedDevice.Backend, workerCount)
	StartAttestationWorkers(workerCount)

	_, _ = tpm.GetVerifiedQuote("orchestrator")

	meshDimensions := 1024
	if raw := os.Getenv("MOHAWK_MESH_DIMENSIONS"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			meshDimensions = parsed
		}
	}

	transportCfg := network.DefaultConfig(defaultPort(os.Getenv("MOHAWK_LIBP2P_PORT"), 4101))
	kexMode, err := network.ParseKEXModeStrict(os.Getenv("MOHAWK_TRANSPORT_KEX_MODE"))
	if err != nil {
		log.Fatalf("MOHAWK_TRANSPORT_KEX_MODE: %v", err)
	}
	metrics.ObservePQCPolicyMode("transport_kex", string(kexMode))
	transportCfg.KEXMode = kexMode
	transportCfg.RelayAddrs = splitRelayAddrs(os.Getenv("MOHAWK_RELAY_ADDRS"))
	transportHost, err := network.NewHost(context.Background(), transportCfg)
	if err != nil {
		log.Fatalf("failed to initialize libp2p host: %v", err)
	}
	defer transportHost.Close()
	log.Printf("orchestrator libp2p peer %s listening on %v", transportHost.ID(), transportHost.Addrs())
	log.Printf("orchestrator transport KEX mode=%s expected_key_bytes=%d", kexMode, kexMode.ExpectedPublicKeyBytes())

	server := &Server{
		Checkpoints:      ipfs.NewBackend(os.Getenv("IPFS_API_ENDPOINT")),
		MeshDimensions:   meshDimensions,
		PeerHost:         transportHost,
		TransportKEXMode: kexMode,
		AdminToken:       loadSecretValue("MOHAWK_ADMIN_TOKEN", "MOHAWK_ADMIN_TOKEN_FILE"),
	}
	utilityLedger, err := initUtilityLedger()
	if err != nil {
		log.Fatalf("failed to initialize utility ledger: %v", err)
	}
	observePQCPolicyMetrics()
	observeThinkerClausesFromCapabilities(defaultString(os.Getenv("MOHAWK_CAPABILITIES_PATH"), "capabilities.json"))
	server.UtilityLedger = utilityLedger
	// Register the libp2p gradient-submission protocol so edge nodes can deliver
	// gradient updates directly over the encrypted p2p transport.
	network.RegisterGradientHandlerWithKEX(transportHost, kexMode, func(msg *network.GradientMessage) *network.GradientAck {
		log.Printf("gradient received: round=%d len=%d node=%s task=%s",
			msg.Round, len(msg.Gradients), sanitizeLogValue(msg.NodeID), sanitizeLogValue(msg.TaskID))
		return &network.GradientAck{Accepted: true, NegotiatedKEX: string(kexMode), KEXPublicKeyLen: kexMode.ExpectedPublicKeyBytes()}
	})

	mux := http.NewServeMux()
	mux.HandleFunc("/orchestrator/pubkey", handlePubkey)
	mux.HandleFunc("/jobs/next", handleNextJob)
	mux.HandleFunc("/attest", server.HandleAttest)
	mux.HandleFunc("/checkpoints/put", server.HandleCheckpointPut)
	mux.HandleFunc("/checkpoints/get", server.HandleCheckpointGet)
	mux.HandleFunc("/mesh/plan", server.HandleMeshPlan)
	mux.HandleFunc("/p2p/info", server.HandleP2PInfo)
	mux.HandleFunc("/ledger/migration/status", server.HandleMigrationStatus)
	mux.HandleFunc("/ledger/migration/config", server.HandleMigrationConfig)
	mux.HandleFunc("/ledger/migration/digest", server.HandleMigrationDigest)
	mux.HandleFunc("/ledger/migration/migrate", server.HandleMigrationTransfer)
	mux.Handle("/metrics", promhttp.Handler())

	metricsAddr := os.Getenv("MOHAWK_METRICS_ADDR")
	if metricsAddr == "" {
		metricsAddr = ":9091"
	}
	go func() {
		metricsMux := http.NewServeMux()
		metricsMux.Handle("/metrics", promhttp.Handler())
		metricsServer := &http.Server{
			Addr:              metricsAddr,
			Handler:           metricsMux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      15 * time.Second,
			IdleTimeout:       60 * time.Second,
		}
		log.Printf("orchestrator metrics listening on %s", sanitizeLogValue(metricsAddr))
		if err := metricsServer.ListenAndServe(); err != nil {
			log.Fatalf("metrics server failed: %v", err)
		}
	}()

	tlsConfig, err := tpm.ServerTLSConfig("orchestrator")
	if err != nil {
		log.Fatalf("failed to initialize mTLS: %v", err)
	}

	httpServer := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		TLSConfig:         tlsConfig,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Println("orchestrator listening with mTLS on :8080")
	log.Fatal(httpServer.ListenAndServeTLS("", ""))
}

func handlePubkey(w http.ResponseWriter, r *http.Request) {
	if _, err := w.Write([]byte(hex.EncodeToString(orchPub))); err != nil {
		log.Printf("failed to write pubkey response: %v", err)
	}
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

func sanitizeLogValue(value string) string {
	if value == "" {
		return ""
	}
	b := strings.Builder{}
	b.Grow(len(value))
	for _, r := range value {
		if r == '\n' || r == '\r' || r == '\t' {
			b.WriteRune(' ')
			continue
		}
		if unicode.IsPrint(r) {
			b.WriteRune(r)
		}
	}
	cleaned := strings.TrimSpace(b.String())
	const maxLen = 120
	if len(cleaned) > maxLen {
		return cleaned[:maxLen] + "..."
	}
	return cleaned
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

func loadSecretValue(envKey string, fileEnvKey string) string {
	if value := strings.TrimSpace(os.Getenv(envKey)); value != "" {
		return value
	}
	secretFile := strings.TrimSpace(os.Getenv(fileEnvKey))
	if secretFile == "" {
		return ""
	}
	secretFile, err := sanitizePathInput(secretFile)
	if err != nil {
		log.Printf("warning: invalid %s path: %v", fileEnvKey, err)
		return ""
	}
	content, err := os.ReadFile(secretFile)
	if err != nil {
		log.Printf("warning: failed to read %s: %v", fileEnvKey, err)
		return ""
	}
	return strings.TrimSpace(string(content))
}

func initUtilityLedger() (*token.Ledger, error) {
	symbol := defaultString(os.Getenv("MOHAWK_UTILITY_SYMBOL"), "MHC")
	minter := defaultString(os.Getenv("MOHAWK_UTILITY_MINTER"), "protocol")
	statePath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_STATE_PATH"))
	auditPath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_AUDIT_PATH"))
	if statePath == "" {
		return token.NewLedger(symbol, minter), nil
	}
	ledger, err := token.NewPersistentLedger(symbol, minter, statePath, auditPath)
	if err != nil {
		return nil, fmt.Errorf("new persistent ledger: %w", err)
	}
	if strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_ENABLED")), "true") {
		eta, _ := time.Parse(time.RFC3339, strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_ETA")))
		epoch, _ := time.Parse(time.RFC3339, strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_EPOCH")))
		lockLegacy := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_LOCK_LEGACY_TRANSFERS")), "true")
		requireCryptoEpoch := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH")), "true")
		ledger.ConfigurePQCMigration(true, eta, lockLegacy)
		ledger.ConfigurePQCMigrationEpoch(epoch, requireCryptoEpoch)
	}
	return ledger, nil
}

func observePQCPolicyMetrics() {
	migrationEnabled := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_ENABLED")), "true")
	lockLegacy := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_LOCK_LEGACY_TRANSFERS")), "true")
	requireCrypto := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_PQC_REQUIRE_CRYPTO_AFTER_EPOCH")), "true")

	metrics.ObservePQCPolicyEnabled("migration_enabled", migrationEnabled)
	metrics.ObservePQCPolicyEnabled("migration_lock_legacy_transfers", lockLegacy)
	metrics.ObservePQCPolicyEnabled("require_crypto_after_epoch", requireCrypto)
	metrics.ObservePQCPolicyMode("tpm_identity_sig_mode", defaultString(os.Getenv("MOHAWK_TPM_IDENTITY_SIG_MODE"), "xmss"))

	if epoch, err := time.Parse(time.RFC3339, strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_EPOCH"))); err == nil {
		metrics.ObservePQCEpochUnix("migration_epoch", epoch.Unix())
	}
	if eta, err := time.Parse(time.RFC3339, strings.TrimSpace(os.Getenv("MOHAWK_PQC_MIGRATION_ETA"))); err == nil {
		metrics.ObservePQCEpochUnix("migration_eta", eta.Unix())
	}
}

func observeThinkerClausesFromCapabilities(path string) {
	cleanPath, err := sanitizePathInput(path)
	if err != nil {
		log.Printf("warning: invalid capabilities path %q: %v", path, err)
		return
	}

	type thinkerClauses struct {
		Enabled                         bool    `json:"enabled"`
		PreserveOutliers                bool    `json:"preserve_outliers"`
		MinorityRetentionMin            float64 `json:"minority_retention_min"`
		MinorityRetentionMax            float64 `json:"minority_retention_max"`
		OutlierDistanceZScoreCap        float64 `json:"outlier_distance_zscore_cap"`
		ManualReviewRequiredAboveZScore float64 `json:"manual_review_required_above_zscore"`
	}
	type capabilities struct {
		Thinker thinkerClauses `json:"thinker_clauses"`
	}

	raw, err := os.ReadFile(cleanPath)
	if err != nil {
		return
	}
	var cfg capabilities
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return
	}
	if cfg.Thinker.Enabled {
		metrics.ObserveThinkerClauseValue("enabled", 1)
	} else {
		metrics.ObserveThinkerClauseValue("enabled", 0)
	}
	if cfg.Thinker.PreserveOutliers {
		metrics.ObserveThinkerClauseValue("preserve_outliers", 1)
	} else {
		metrics.ObserveThinkerClauseValue("preserve_outliers", 0)
	}
	metrics.ObserveThinkerClauseValue("minority_retention_min", cfg.Thinker.MinorityRetentionMin)
	metrics.ObserveThinkerClauseValue("minority_retention_max", cfg.Thinker.MinorityRetentionMax)
	metrics.ObserveThinkerClauseValue("outlier_distance_zscore_cap", cfg.Thinker.OutlierDistanceZScoreCap)
	metrics.ObserveThinkerClauseValue("manual_review_required_above_zscore", cfg.Thinker.ManualReviewRequiredAboveZScore)
}

func sanitizePathInput(raw string) (string, error) {
	path := strings.TrimSpace(raw)
	if path == "" {
		return "", fmt.Errorf("path is empty")
	}
	if strings.Contains(path, "\x00") {
		return "", fmt.Errorf("path contains NUL byte")
	}
	for _, part := range strings.Split(path, string(filepath.Separator)) {
		if part == ".." {
			return "", fmt.Errorf("path traversal segment is not allowed")
		}
	}
	cleaned := filepath.Clean(path)
	if cleaned == "." || cleaned == ".." {
		return "", fmt.Errorf("path does not resolve to a file")
	}
	return cleaned, nil
}
