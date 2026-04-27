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
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode"

	corehost "github.com/libp2p/go-libp2p/core/host"
	libp2ppeer "github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/wasmhost"
)

// Config simulates the capability manifest for a 10M-node edge participant.
type Config struct {
	WasmModulePath            string
	AllowInsecureWASMFallback bool
	NodeID                    string
	OrchestratorURL           string
	OrchestratorServerName    string
	RouterURL                 string
	RouterSourceVertical      string
	RouterTargetVertical      string
	RouterModelID             string
	LibP2PPort                int
	TransportKEXMode          network.KEXMode
	RelayAddrs                []string
	IPFSEndpoint              string
	TotalNodes                int
	MeshDimensions            int
}

func main() {
	log.Println("Sovereign-Mohawk Node Agent starting...")

	conf, err := loadConfig()
	if err != nil {
		log.Fatalf("Critical Failure: Invalid node-agent config: %v", err)
	}
	tune := accelerator.BuildAutoTuneProfile(0)
	if tune.RecommendedWorker > 0 {
		runtime.GOMAXPROCS(tune.RecommendedWorker)
	}
	metrics.ObserveAggregationWorkers(runtime.GOMAXPROCS(0))
	log.Printf("Node %s autotune selected backend=%s workers=%d format=%s", conf.NodeID, tune.SelectedDevice.Backend, runtime.GOMAXPROCS(0), tune.PreferredFormat)
	startMetricsServer(conf.NodeID)
	rootCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	ctx, cancel := context.WithTimeout(rootCtx, 30*time.Second)
	defer cancel()

	hostCfg := network.DefaultConfig(conf.LibP2PPort)
	hostCfg.RelayAddrs = conf.RelayAddrs
	hostCfg.KEXMode = conf.TransportKEXMode
	peerHost, err := network.NewHost(ctx, hostCfg)
	if err != nil {
		log.Fatalf("Critical Failure: Could not initialize libp2p host: %v", err)
	}
	defer peerHost.Close()
	log.Printf("Node %s libp2p peer %s listening on %v", conf.NodeID, peerHost.ID(), peerHost.Addrs())
	log.Printf("Node %s transport KEX mode=%s expected_key_bytes=%d", conf.NodeID, conf.TransportKEXMode, conf.TransportKEXMode.ExpectedPublicKeyBytes())

	meshPlan, err := hva.BuildPlan(conf.TotalNodes, conf.MeshDimensions)
	if err != nil {
		log.Fatalf("Critical Failure: Could not derive HVA plan: %v", err)
	}
	log.Printf("HVA plan active: %d levels, branch factor %d", len(meshPlan.Levels), meshPlan.BranchFactor)

	quote, err := tpm.GetVerifiedQuote(conf.NodeID)
	if err != nil {
		log.Fatalf("Critical Failure: Could not generate TPM quote: %v", err)
	}
	if err := tpm.Verify(conf.NodeID, quote); err != nil {
		log.Fatalf("Critical Failure: Local TPM verification failed: %v", err)
	}

	if err := submitAttestation(ctx, conf, quote); err != nil {
		log.Printf("Attestation submission deferred: %v", err)
	}
	if err := checkpointNodeState(ctx, conf, meshPlan, peerHost.Addrs(), quote); err != nil {
		log.Printf("Checkpoint publish deferred: %v", err)
	}
	if err := publishRouterHeartbeat(ctx, conf, meshPlan, quote, 0); err != nil {
		log.Printf("Router publish deferred: %v", err)
	}

	wasmBin, err := loadVerifierModule(conf)
	if err != nil {
		log.Fatalf("Critical Failure: Could not load verifier module: %v", err)
	}

	runner, err := wasmhost.NewRunner(ctx, wasmBin)
	if err != nil {
		log.Fatalf("Critical Failure: Could not initialize Wasm Runner: %v", err)
	}
	defer runner.Close(ctx)

	activeVerifier := runner

	log.Printf("Node %s successfully initialized with zk-SNARK verifier and transport stack", conf.NodeID)

	mockProof := make([]byte, 200)
	proofStart := time.Now()
	success, err := runner.Verify(ctx, mockProof)
	proofLatency := float64(time.Since(proofStart).Microseconds()) / 1000.0
	if err != nil {
		if isMissingVerifyProofExportErr(err) {
			if conf.AllowInsecureWASMFallback {
				log.Printf("Warning: Wasm verifier at %s does not export verify_proof; using insecure fallback verifier due to MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true", conf.WasmModulePath)
				fallbackRunner, fallbackErr := wasmhost.NewRunner(ctx, insecureFallbackVerifierModule())
				if fallbackErr != nil {
					log.Fatalf("Critical Failure: Could not initialize insecure fallback verifier: %v", fallbackErr)
				}
				_ = runner.Close(ctx)
				runner = fallbackRunner
				activeVerifier = fallbackRunner
			} else {
				log.Fatalf("Critical Failure: Wasm verifier at %s does not export verify_proof", conf.WasmModulePath)
			}
		} else {
			metrics.ObserveProofVerification("groth16", false, proofLatency)
			metrics.ObserveAcceleratorOp(string(tune.SelectedDevice.Backend), "proof_verify", false)
			metrics.ObserveAcceleratorOpLatency(string(tune.SelectedDevice.Backend), "proof_verify", proofLatency)
			log.Printf("Verification Process Executed: %v", err)
		}
	} else {
		metrics.ObserveProofVerification("groth16", success, proofLatency)
		metrics.ObserveAcceleratorOp(string(tune.SelectedDevice.Backend), "proof_verify", success)
		metrics.ObserveAcceleratorOpLatency(string(tune.SelectedDevice.Backend), "proof_verify", proofLatency)
		log.Printf("Theorem 5 Verification Status: %v", success)
	}

	// Submit an initial gradient update over the libp2p transport.
	sendGradientUpdate(ctx, conf, meshPlan, peerHost, 1)

	// Enumerate hardware accelerators and log available backends.
	logAcceleratorDevices()

	log.Println("Node Agent operational. Entering supervised runtime loop...")
	runSupervisor(rootCtx, conf, meshPlan, peerHost, activeVerifier)
}

func runSupervisor(rootCtx context.Context, conf Config, meshPlan hva.Plan, peerHost corehost.Host, runner *wasmhost.Host) {
	interval := time.Duration(defaultInt(os.Getenv("MOHAWK_SUPERVISOR_INTERVAL_SECONDS"), 30)) * time.Second
	if interval < 5*time.Second {
		interval = 5 * time.Second
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	round := 1
	consecutiveFailures := 0

	for {
		if err := runSupervisedRound(rootCtx, conf, meshPlan, peerHost, runner, round); err != nil {
			consecutiveFailures++
			backoff := time.Duration(consecutiveFailures)
			if backoff > 10 {
				backoff = 10
			}
			log.Printf("Supervisor round %d failed: %v (consecutive=%d)", round, err, consecutiveFailures)
			select {
			case <-rootCtx.Done():
				return
			case <-time.After(backoff * time.Second):
			}
		} else {
			consecutiveFailures = 0
		}
		round++

		select {
		case <-rootCtx.Done():
			log.Println("Node Agent supervisor stopping by signal")
			return
		case <-ticker.C:
		}
	}
}

func runSupervisedRound(rootCtx context.Context, conf Config, meshPlan hva.Plan, peerHost corehost.Host, runner *wasmhost.Host, round int) (err error) {
	defer func() {
		if recovered := recover(); recovered != nil {
			err = fmt.Errorf("panic recovered in supervisor round: %v", recovered)
		}
	}()

	roundCtx, cancel := context.WithTimeout(rootCtx, 20*time.Second)
	defer cancel()

	quote, err := tpm.GetVerifiedQuote(conf.NodeID)
	if err != nil {
		return fmt.Errorf("quote generation failed: %w", err)
	}
	if err := tpm.Verify(conf.NodeID, quote); err != nil {
		return fmt.Errorf("local quote verification failed: %w", err)
	}

	if err := submitAttestation(roundCtx, conf, quote); err != nil {
		log.Printf("Supervisor: attestation deferred: %v", err)
	}
	if err := checkpointNodeState(roundCtx, conf, meshPlan, peerHost.Addrs(), quote); err != nil {
		log.Printf("Supervisor: checkpoint deferred: %v", err)
	}
	if err := publishRouterHeartbeat(roundCtx, conf, meshPlan, quote, round); err != nil {
		log.Printf("Supervisor: router publish deferred: %v", err)
	}

	if runner != nil {
		mockProof := make([]byte, 200)
		proofStart := time.Now()
		proofOK, proofErr := runner.Verify(roundCtx, mockProof)
		proofLatency := float64(time.Since(proofStart).Microseconds()) / 1000.0
		if proofErr != nil {
			metrics.ObserveProofVerification("groth16", false, proofLatency)
			metrics.ObserveAcceleratorOp("cpu", "proof_verify", false)
			metrics.ObserveAcceleratorOpLatency("cpu", "proof_verify", proofLatency)
			log.Printf("Supervisor: proof verify failed: %v", proofErr)
		} else {
			metrics.ObserveProofVerification("groth16", proofOK, proofLatency)
			metrics.ObserveAcceleratorOp("cpu", "proof_verify", proofOK)
			metrics.ObserveAcceleratorOpLatency("cpu", "proof_verify", proofLatency)
		}
	}

	sendGradientUpdate(roundCtx, conf, meshPlan, peerHost, round)
	return nil
}

func isMissingVerifyProofExportErr(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "missing required export: verify_proof")
}

// logAcceleratorDevices detects and logs hardware compute backends.
func logAcceleratorDevices() {
	devices := accelerator.DetectDevices()
	for _, d := range devices {
		log.Printf("Accelerator: backend=%s name=%q simd_width=%d", d.Backend, d.Name, d.SIMDWidth)
	}
}

// p2pInfo holds the orchestrator's libp2p peer ID and multiaddrs.
type p2pInfo struct {
	PeerID                 string   `json:"peer_id"`
	Addrs                  []string `json:"addrs"`
	KEXMode                string   `json:"kex_mode,omitempty"`
	ExpectedPublicKeyBytes int      `json:"expected_public_key_bytes,omitempty"`
}

// fetchP2PInfo retrieves the orchestrator's libp2p peer ID and listen addresses via HTTPS.
func fetchP2PInfo(ctx context.Context, conf Config) (*p2pInfo, error) {
	if conf.OrchestratorURL == "" {
		return nil, fmt.Errorf("ORCHESTRATOR_URL not set")
	}
	tlsConfig, err := tpm.ClientTLSConfig(conf.NodeID, conf.OrchestratorServerName)
	if err != nil {
		return nil, err
	}
	client := &http.Client{
		Timeout: 5 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		strings.TrimRight(conf.OrchestratorURL, "/")+"/p2p/info", nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("p2p/info returned %s", resp.Status)
	}
	var info p2pInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, err
	}
	return &info, nil
}

// sendGradientUpdate fetches the orchestrator's libp2p address, dials it, and delivers
// a gradient update message over the /mohawk/gradient/1.0.0 protocol.
func sendGradientUpdate(ctx context.Context, conf Config, plan hva.Plan, peerHost corehost.Host, round int) {
	gradStart := time.Now()
	info, err := fetchP2PInfo(ctx, conf)
	if err != nil {
		metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
		metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
		log.Printf("Gradient: could not fetch orchestrator p2p info: %v", err)
		return
	}
	if strings.TrimSpace(info.KEXMode) != "" {
		remoteMode := network.ParseKEXMode(info.KEXMode)
		if remoteMode == "" {
			metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
			metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
			log.Printf("Gradient: orchestrator advertised unsupported KEX mode=%q", sanitizeLogValue(info.KEXMode))
			return
		}
		if remoteMode != conf.TransportKEXMode {
			metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
			metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
			log.Printf("Gradient: KEX mismatch local=%s remote=%s; skipping gradient submit", conf.TransportKEXMode, remoteMode)
			return
		}
		if info.ExpectedPublicKeyBytes > 0 && info.ExpectedPublicKeyBytes != conf.TransportKEXMode.ExpectedPublicKeyBytes() {
			metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
			metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
			log.Printf("Gradient: KEX key-size mismatch local=%d remote=%d; skipping gradient submit", conf.TransportKEXMode.ExpectedPublicKeyBytes(), info.ExpectedPublicKeyBytes)
			return
		}
	}
	orchPeerID, err := libp2ppeer.Decode(info.PeerID)
	if err != nil {
		metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
		metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
		log.Printf("Gradient: invalid orchestrator peer ID=%q: %v", sanitizeLogValue(info.PeerID), err)
		return
	}
	orchAddrs := make([]multiaddr.Multiaddr, 0, len(info.Addrs))
	for _, a := range info.Addrs {
		ma, err := multiaddr.NewMultiaddr(a)
		if err != nil {
			log.Printf("Gradient: skipping invalid addr=%q: %v", sanitizeLogValue(a), err)
			continue
		}
		orchAddrs = append(orchAddrs, ma)
	}
	mockGradients := make([]float64, 128)
	msg := &network.GradientMessage{
		NodeID:    conf.NodeID,
		TaskID:    "task-init",
		Round:     round,
		Gradients: mockGradients,
	}
	ack, err := network.SendGradientWithKEX(ctx, peerHost, orchPeerID, orchAddrs, msg, conf.TransportKEXMode)
	if err != nil {
		metrics.ObserveAcceleratorOp("cpu", "gradient_submit", false)
		metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
		log.Printf("Gradient: submission failed: %v", err)
		return
	}
	metrics.ObserveAcceleratorOp("cpu", "gradient_submit", ack.Accepted)
	metrics.ObserveAcceleratorOpLatency("cpu", "gradient_submit", float64(time.Since(gradStart).Microseconds())/1000.0)
	if !ack.Accepted {
		log.Printf("Gradient: sent round=%d len=%d -> accepted=%v reason=%q negotiated_kex=%q kex_pubkey_len=%d", msg.Round, len(msg.Gradients), ack.Accepted, sanitizeLogValue(ack.Reason), sanitizeLogValue(ack.NegotiatedKEX), ack.KEXPublicKeyLen)
		return
	}
	log.Printf("Gradient: sent round=%d len=%d -> accepted=%v negotiated_kex=%q kex_pubkey_len=%d", msg.Round, len(msg.Gradients), ack.Accepted, sanitizeLogValue(ack.NegotiatedKEX), ack.KEXPublicKeyLen)
}

func startMetricsServer(nodeID string) {
	metricsAddr := strings.TrimSpace(os.Getenv("MOHAWK_NODE_METRICS_ADDR"))
	if metricsAddr == "" {
		metricsAddr = ":9100"
	}
	go func() {
		mux := http.NewServeMux()
		mux.Handle("/metrics", promhttp.Handler())
		server := &http.Server{
			Addr:              metricsAddr,
			Handler:           mux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      15 * time.Second,
			IdleTimeout:       60 * time.Second,
		}
		log.Printf("Node %s metrics listening on %s", sanitizeLogValue(nodeID), sanitizeLogValue(metricsAddr))
		if err := server.ListenAndServe(); err != nil {
			log.Printf("Node %s metrics server stopped: %v", sanitizeLogValue(nodeID), err)
		}
	}()
}

func loadConfig() (Config, error) {
	kexMode, err := network.ParseKEXModeStrict(os.Getenv("MOHAWK_TRANSPORT_KEX_MODE"))
	if err != nil {
		return Config{}, fmt.Errorf("MOHAWK_TRANSPORT_KEX_MODE: %w", err)
	}
	allowInsecureFallback := strings.EqualFold(strings.TrimSpace(os.Getenv("MOHAWK_ALLOW_INSECURE_WASM_FALLBACK")), "true")
	return Config{
		WasmModulePath:            defaultString(os.Getenv("WASM_MODULE_PATH"), "proof_verifier.wasm"),
		AllowInsecureWASMFallback: allowInsecureFallback,
		NodeID:                    defaultString(os.Getenv("NODE_ID"), "edge-node-001"),
		OrchestratorURL:           os.Getenv("ORCHESTRATOR_URL"),
		OrchestratorServerName:    defaultString(os.Getenv("ORCHESTRATOR_SERVER_NAME"), "orchestrator"),
		RouterURL:                 defaultString(strings.TrimSpace(os.Getenv("MOHAWK_ROUTER_URL")), "http://federated-router:8087"),
		RouterSourceVertical:      defaultString(strings.TrimSpace(os.Getenv("MOHAWK_ROUTER_SOURCE_VERTICAL")), "climate"),
		RouterTargetVertical:      defaultString(strings.TrimSpace(os.Getenv("MOHAWK_ROUTER_TARGET_VERTICAL")), "supply-chain"),
		RouterModelID:             defaultString(strings.TrimSpace(os.Getenv("MOHAWK_ROUTER_MODEL_ID")), "node-agent-federated-insight"),
		LibP2PPort:                defaultInt(os.Getenv("MOHAWK_LIBP2P_PORT"), 4001),
		TransportKEXMode:          kexMode,
		RelayAddrs:                splitCSV(os.Getenv("MOHAWK_RELAY_ADDRS")),
		IPFSEndpoint:              os.Getenv("IPFS_API_ENDPOINT"),
		TotalNodes:                defaultInt(os.Getenv("MOHAWK_TOTAL_NODES"), 10000000),
		MeshDimensions:            defaultInt(os.Getenv("MOHAWK_MESH_DIMENSIONS"), 1024),
	}, nil
}

func loadVerifierModule(conf Config) ([]byte, error) {
	wasmBin, err := os.ReadFile(conf.WasmModulePath)
	if err == nil {
		return wasmBin, nil
	}
	if conf.AllowInsecureWASMFallback {
		log.Printf("Warning: Wasm module not found at %s; using insecure fallback verifier due to MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true", conf.WasmModulePath)
		return insecureFallbackVerifierModule(), nil
	}
	return nil, fmt.Errorf("wasm module not found at %s (set MOHAWK_ALLOW_INSECURE_WASM_FALLBACK=true for CI/dev only): %w", conf.WasmModulePath, err)
}

func insecureFallbackVerifierModule() []byte {
	// Minimal wasm module exporting verify_proof(i32) -> i32 that returns 0.
	return []byte{
		0x00, 0x61, 0x73, 0x6d,
		0x01, 0x00, 0x00, 0x00,
		0x01, 0x06, 0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f,
		0x03, 0x02, 0x01, 0x00,
		0x07, 0x10, 0x01, 0x0c,
		0x76, 0x65, 0x72, 0x69, 0x66, 0x79, 0x5f, 0x70, 0x72, 0x6f, 0x6f, 0x66,
		0x00, 0x00,
		0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x00, 0x0b,
	}
}

func submitAttestation(ctx context.Context, conf Config, quote []byte) error {
	if conf.OrchestratorURL == "" {
		return nil
	}
	tlsConfig, err := tpm.ClientTLSConfig(conf.NodeID, conf.OrchestratorServerName)
	if err != nil {
		return err
	}
	body, err := json.Marshal(map[string]any{
		"node_id": conf.NodeID,
		"quote":   quote,
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(conf.OrchestratorURL, "/")+"/attest", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusBadRequest {
		return fmt.Errorf("attestation endpoint returned %s", resp.Status)
	}
	return nil
}

func checkpointNodeState(ctx context.Context, conf Config, plan hva.Plan, addrs []multiaddr.Multiaddr, quote []byte) error {
	if conf.IPFSEndpoint == "" {
		return nil
	}
	backend := ipfs.NewBackend(conf.IPFSEndpoint)
	payload := map[string]any{
		"node_id":       conf.NodeID,
		"mesh_levels":   len(plan.Levels),
		"branch_factor": plan.BranchFactor,
		"peer_addrs":    stringifyAddrs(addrs),
		"quote_len":     len(quote),
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = backend.PutCheckpoint(ctx, conf.NodeID+"-checkpoint.json", encoded)
	return err
}

func publishRouterHeartbeat(ctx context.Context, conf Config, plan hva.Plan, quote []byte, round int) error {
	if conf.RouterURL == "" {
		return nil
	}
	offerID := fmt.Sprintf("%s-round-%d", conf.NodeID, round)
	payload := map[string]any{
		"offer_id":            offerID,
		"source_vertical":     conf.RouterSourceVertical,
		"model_id":            conf.RouterModelID,
		"summary":             fmt.Sprintf("Node %s heartbeat with %d mesh levels", conf.NodeID, len(plan.Levels)),
		"publisher_node_id":   conf.NodeID,
		"publisher_quote":     quote,
		"expected_proof_root": "",
	}
	if err := postRouterJSON(ctx, conf.RouterURL, "/router/publish", payload); err != nil {
		return err
	}

	prov := map[string]any{
		"offer_id":         offerID,
		"source_vertical":  conf.RouterSourceVertical,
		"target_vertical":  conf.RouterTargetVertical,
		"subscriber_model": "node-agent-runtime",
		"impact_metric":    "mesh_level_count",
		"impact_delta":     float64(len(plan.Levels)),
	}
	return postRouterJSON(ctx, conf.RouterURL, "/router/provenance", prov)
}

func postRouterJSON(ctx context.Context, baseURL string, path string, payload map[string]any) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusBadRequest {
		return fmt.Errorf("router endpoint %s returned %s", path, resp.Status)
	}
	return nil
}

func stringifyAddrs(addrs []multiaddr.Multiaddr) []string {
	values := make([]string, 0, len(addrs))
	for _, addr := range addrs {
		values = append(values, addr.String())
	}
	return values
}

func defaultString(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func defaultInt(value string, fallback int) int {
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func splitCSV(value string) []string {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
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
