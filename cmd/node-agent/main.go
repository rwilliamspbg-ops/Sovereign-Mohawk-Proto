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
	"strconv"
	"strings"
	"syscall"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	libp2ppeer "github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/ipfs"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/wasmhost"
)

// Config simulates the capability manifest for a 10M-node edge participant.
type Config struct {
	WasmModulePath         string
	NodeID                 string
	OrchestratorURL        string
	OrchestratorServerName string
	LibP2PPort             int
	RelayAddrs             []string
	IPFSEndpoint           string
	TotalNodes             int
	MeshDimensions         int
}

func main() {
	log.Println("Sovereign-Mohawk Node Agent starting...")

	conf := loadConfig()
	rootCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	ctx, cancel := context.WithTimeout(rootCtx, 30*time.Second)
	defer cancel()

	hostCfg := network.DefaultConfig(conf.LibP2PPort)
	hostCfg.RelayAddrs = conf.RelayAddrs
	peerHost, err := network.NewHost(ctx, hostCfg)
	if err != nil {
		log.Fatalf("Critical Failure: Could not initialize libp2p host: %v", err)
	}
	defer peerHost.Close()
	log.Printf("Node %s libp2p peer %s listening on %v", conf.NodeID, peerHost.ID(), peerHost.Addrs())

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

	wasmBin, err := os.ReadFile(conf.WasmModulePath)
	if err != nil {
		log.Printf("Warning: Wasm module not found at %s, creating mock for CI...", conf.WasmModulePath)
		wasmBin = []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	}

	runner, err := wasmhost.NewRunner(ctx, wasmBin)
	if err != nil {
		log.Fatalf("Critical Failure: Could not initialize Wasm Runner: %v", err)
	}
	defer runner.Close(ctx)

	log.Printf("Node %s successfully initialized with zk-SNARK verifier and transport stack", conf.NodeID)

	mockProof := make([]byte, 200)
	success, err := runner.Verify(ctx, mockProof)
	if err != nil {
		log.Printf("Verification Process Executed: %v", err)
	} else {
		log.Printf("Theorem 5 Verification Status: %v", success)
	}

	// Submit an initial gradient update over the libp2p transport.
	sendGradientUpdate(ctx, conf, meshPlan, peerHost, 1)

	// Enumerate hardware accelerators and log available backends.
	logAcceleratorDevices()

	log.Println("Node Agent operational. Entering supervised runtime loop...")
	runSupervisor(rootCtx, conf, meshPlan, peerHost, runner)
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

	mockProof := make([]byte, 200)
	if _, err := runner.Verify(roundCtx, mockProof); err != nil {
		log.Printf("Supervisor: proof verify failed: %v", err)
	}

	sendGradientUpdate(roundCtx, conf, meshPlan, peerHost, round)
	return nil
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
	PeerID string   `json:"peer_id"`
	Addrs  []string `json:"addrs"`
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
	info, err := fetchP2PInfo(ctx, conf)
	if err != nil {
		log.Printf("Gradient: could not fetch orchestrator p2p info: %v", err)
		return
	}
	orchPeerID, err := libp2ppeer.Decode(info.PeerID)
	if err != nil {
		log.Printf("Gradient: invalid orchestrator peer ID %q: %v", info.PeerID, err)
		return
	}
	orchAddrs := make([]multiaddr.Multiaddr, 0, len(info.Addrs))
	for _, a := range info.Addrs {
		ma, err := multiaddr.NewMultiaddr(a)
		if err != nil {
			log.Printf("Gradient: skipping invalid addr %q: %v", a, err)
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
	ack, err := network.SendGradient(ctx, peerHost, orchPeerID, orchAddrs, msg)
	if err != nil {
		log.Printf("Gradient: submission failed: %v", err)
		return
	}
	log.Printf("Gradient: sent round=%d len=%d -> accepted=%v", msg.Round, len(msg.Gradients), ack.Accepted)
}

func loadConfig() Config {
	return Config{
		WasmModulePath:         defaultString(os.Getenv("WASM_MODULE_PATH"), "proof_verifier.wasm"),
		NodeID:                 defaultString(os.Getenv("NODE_ID"), "edge-node-001"),
		OrchestratorURL:        os.Getenv("ORCHESTRATOR_URL"),
		OrchestratorServerName: defaultString(os.Getenv("ORCHESTRATOR_SERVER_NAME"), "orchestrator"),
		LibP2PPort:             defaultInt(os.Getenv("MOHAWK_LIBP2P_PORT"), 4001),
		RelayAddrs:             splitCSV(os.Getenv("MOHAWK_RELAY_ADDRS")),
		IPFSEndpoint:           os.Getenv("IPFS_API_ENDPOINT"),
		TotalNodes:             defaultInt(os.Getenv("MOHAWK_TOTAL_NODES"), 10000000),
		MeshDimensions:         defaultInt(os.Getenv("MOHAWK_MESH_DIMENSIONS"), 1024),
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
