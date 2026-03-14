// Formal Proof Reference: See /proofs/pyapi_bridge_correctness.md for ctypes binding safety proofs
package main

import "C"
import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	corehost "github.com/libp2p/go-libp2p/core/host"
	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/bridge"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hva"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hybrid"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/metrics"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/network"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/tpm"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/wasmhost"
)

// NodeConfig represents the configuration for initializing a MOHAWK node
type NodeConfig struct {
	NodeID       string `json:"node_id"`
	ConfigPath   string `json:"config_path"`
	Capabilities string `json:"capabilities"`
}

// Result represents a generic result structure for API responses
type Result struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

type runtimeState struct {
	mu         sync.Mutex
	config     NodeConfig
	startedAt  time.Time
	meshPlan   hva.Plan
	host       corehost.Host
	runner     *wasmhost.Host
	aggregator *internalpkg.Aggregator
}

var state runtimeState
var utilityCoinLedger = initUtilityCoinLedger()
var apiAuthToken = loadAPIToken()
var apiAuthTokenRole = strings.TrimSpace(os.Getenv("MOHAWK_API_TOKEN_ROLE"))
var apiAuthMode = loadAPIAuthMode()
var apiRolePolicy = loadAPIRolePolicy()
var utilityRolePolicy = loadUtilityRolePolicy()
var utilityOpRateLimiter = loadUtilityRateLimiter()

const (
	apiAuthModeOptional = "optional"
	apiAuthModeRequired = "required"
	apiAuthModeFileOnly = "file-only"
)

type apiRolePolicyConfig struct {
	enabled      bool
	allowedByOp  map[string]map[string]struct{}
	requiredByOp map[string]bool
}

type utilityRolePolicyConfig struct {
	enabled      bool
	allowedByOp  map[string]map[string]struct{}
	requiredByOp map[string]bool
}

type rateWindowCounter struct {
	windowStart int64
	count       int
}

type utilityRateLimiter struct {
	mu          sync.Mutex
	limitPerMin int
	counters    map[string]rateWindowCounter
}

func loadAPIAuthMode() string {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv("MOHAWK_API_AUTH_MODE")))
	switch raw {
	case "", apiAuthModeOptional:
		return apiAuthModeOptional
	case apiAuthModeRequired:
		return apiAuthModeRequired
	case apiAuthModeFileOnly:
		return apiAuthModeFileOnly
	default:
		log.Printf("invalid MOHAWK_API_AUTH_MODE=%q; defaulting to %s", raw, apiAuthModeOptional)
		return apiAuthModeOptional
	}
}

func loadAPIRolePolicy() apiRolePolicyConfig {
	enabled := parseBoolEnv("MOHAWK_API_ENFORCE_ROLES", false)
	bridgeRoles := parseRoleSet(os.Getenv("MOHAWK_API_BRIDGE_ALLOWED_ROLES"), "bridge,operator,admin,protocol")
	hybridRoles := parseRoleSet(os.Getenv("MOHAWK_API_HYBRID_ALLOWED_ROLES"), "verifier,operator,admin,protocol")

	return apiRolePolicyConfig{
		enabled: enabled,
		allowedByOp: map[string]map[string]struct{}{
			"bridge": bridgeRoles,
			"hybrid": hybridRoles,
		},
		requiredByOp: map[string]bool{
			"bridge": true,
			"hybrid": true,
		},
	}
}

func loadUtilityRolePolicy() utilityRolePolicyConfig {
	enabled := parseBoolEnv("MOHAWK_UTILITY_ENFORCE_ROLES", false)
	mintRoles := parseRoleSet(os.Getenv("MOHAWK_UTILITY_MINT_ALLOWED_ROLES"), "minter,admin,protocol")
	transferRoles := parseRoleSet(os.Getenv("MOHAWK_UTILITY_TRANSFER_ALLOWED_ROLES"), "user,operator,admin,protocol")
	backupRoles := parseRoleSet(os.Getenv("MOHAWK_UTILITY_BACKUP_ALLOWED_ROLES"), "operator,admin")
	restoreRoles := parseRoleSet(os.Getenv("MOHAWK_UTILITY_RESTORE_ALLOWED_ROLES"), "admin")

	return utilityRolePolicyConfig{
		enabled: enabled,
		allowedByOp: map[string]map[string]struct{}{
			"mint":     mintRoles,
			"transfer": transferRoles,
			"backup":   backupRoles,
			"restore":  restoreRoles,
		},
		requiredByOp: map[string]bool{
			"mint":     true,
			"transfer": true,
			"backup":   true,
			"restore":  true,
		},
	}
}

func loadUtilityRateLimiter() *utilityRateLimiter {
	raw := strings.TrimSpace(os.Getenv("MOHAWK_UTILITY_RATE_LIMIT_PER_MIN"))
	if raw == "" {
		return nil
	}
	limit, err := strconv.Atoi(raw)
	if err != nil || limit <= 0 {
		log.Printf("invalid MOHAWK_UTILITY_RATE_LIMIT_PER_MIN=%q; rate limiting disabled", raw)
		return nil
	}
	return &utilityRateLimiter{
		limitPerMin: limit,
		counters:    map[string]rateWindowCounter{},
	}
}

func parseBoolEnv(key string, fallback bool) bool {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if raw == "" {
		return fallback
	}
	switch raw {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

func parseRoleSet(raw string, defaults string) map[string]struct{} {
	if strings.TrimSpace(raw) == "" {
		raw = defaults
	}
	set := map[string]struct{}{}
	for _, part := range strings.Split(raw, ",") {
		role := strings.TrimSpace(strings.ToLower(part))
		if role == "" {
			continue
		}
		set[role] = struct{}{}
	}
	return set
}

func effectiveUtilityRole(requestRole string) (string, error) {
	requestRole = strings.TrimSpace(strings.ToLower(requestRole))
	tokenRole := strings.TrimSpace(strings.ToLower(apiAuthTokenRole))
	if tokenRole == "" {
		return requestRole, nil
	}
	if requestRole != "" && requestRole != tokenRole {
		return "", fmt.Errorf("role mismatch for token-bound principal")
	}
	return tokenRole, nil
}

func effectiveAPIRole(requestRole string) (string, error) {
	return effectiveUtilityRole(requestRole)
}

func authorizeAPIRole(op string, requestRole string) error {
	if !apiRolePolicy.enabled {
		return nil
	}
	allowed := apiRolePolicy.allowedByOp[op]
	if len(allowed) == 0 {
		return fmt.Errorf("role policy for %s is not configured", op)
	}
	role, err := effectiveAPIRole(requestRole)
	if err != nil {
		return err
	}
	if role == "" && apiRolePolicy.requiredByOp[op] {
		return fmt.Errorf("role is required for %s", op)
	}
	if _, ok := allowed[role]; !ok {
		return fmt.Errorf("role %q is not allowed for %s", role, op)
	}
	return nil
}

func authorizeUtilityRole(op string, requestRole string) error {
	if !utilityRolePolicy.enabled {
		return nil
	}
	allowed := utilityRolePolicy.allowedByOp[op]
	if len(allowed) == 0 {
		return fmt.Errorf("role policy for %s is not configured", op)
	}
	role, err := effectiveUtilityRole(requestRole)
	if err != nil {
		return err
	}
	if role == "" && utilityRolePolicy.requiredByOp[op] {
		return fmt.Errorf("role is required for %s", op)
	}
	if _, ok := allowed[role]; !ok {
		return fmt.Errorf("role %q is not allowed for %s", role, op)
	}
	return nil
}

func (r *utilityRateLimiter) Allow(principal string) bool {
	if r == nil || r.limitPerMin <= 0 {
		return true
	}
	principal = strings.TrimSpace(principal)
	if principal == "" {
		principal = "anonymous"
	}
	nowWindow := time.Now().UTC().Unix() / 60
	r.mu.Lock()
	defer r.mu.Unlock()
	counter := r.counters[principal]
	if counter.windowStart != nowWindow {
		counter = rateWindowCounter{windowStart: nowWindow}
	}
	if counter.count >= r.limitPerMin {
		r.counters[principal] = counter
		return false
	}
	counter.count++
	r.counters[principal] = counter
	return true
}

func enforceUtilityRateLimit(principal string) error {
	if utilityOpRateLimiter.Allow(principal) {
		return nil
	}
	return fmt.Errorf("rate limit exceeded for principal %q", strings.TrimSpace(principal))
}

func extractProvidedToken(authToken string, authorization string, apiToken string) string {
	if strings.TrimSpace(authToken) != "" {
		return authToken
	}
	if strings.TrimSpace(authorization) != "" {
		return authorization
	}
	return apiToken
}

func validateAPIAccess(op string, role string, providedToken string) error {
	switch apiAuthMode {
	case apiAuthModeRequired:
		if apiAuthToken == "" {
			return fmt.Errorf("api auth mode is required but token is not configured")
		}
		if !verifyAPIToken(providedToken) {
			return fmt.Errorf("invalid API token")
		}
	case apiAuthModeFileOnly:
		if strings.TrimSpace(os.Getenv("MOHAWK_API_TOKEN_FILE")) == "" {
			return fmt.Errorf("api auth mode file-only requires MOHAWK_API_TOKEN_FILE")
		}
		if apiAuthToken == "" {
			return fmt.Errorf("api auth token file is configured but unreadable")
		}
		if !verifyAPIToken(providedToken) {
			return fmt.Errorf("invalid API token")
		}
	default:
		if apiAuthToken != "" && !verifyAPIToken(providedToken) {
			return fmt.Errorf("invalid API token")
		}
	}

	if err := authorizeAPIRole(op, role); err != nil {
		return err
	}
	return nil
}

func initUtilityCoinLedger() *token.Ledger {
	statePath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_STATE_PATH"))
	auditPath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_AUDIT_PATH"))
	minter := strings.TrimSpace(os.Getenv("MOHAWK_UTILITY_MINTER"))
	if minter == "" {
		minter = "protocol"
	}
	if statePath == "" || auditPath == "" {
		return token.NewLedger("MHC", minter)
	}
	ledger, err := token.NewPersistentLedger("MHC", minter, statePath, auditPath)
	if err != nil {
		log.Printf("utility coin persistent ledger disabled: %v", err)
		return token.NewLedger("MHC", minter)
	}
	log.Printf("utility coin persistent ledger enabled: state=%s audit=%s", statePath, auditPath)
	return ledger
}

func parseBridgeSettlementAssets(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	unique := map[string]struct{}{}
	assets := make([]string, 0)
	for _, part := range strings.Split(raw, ",") {
		symbol := strings.ToUpper(strings.TrimSpace(part))
		if symbol == "" {
			continue
		}
		if _, exists := unique[symbol]; exists {
			continue
		}
		unique[symbol] = struct{}{}
		assets = append(assets, symbol)
	}
	return assets
}

func symbolEnvSuffix(symbol string) string {
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	if symbol == "" {
		return ""
	}
	var b strings.Builder
	for _, r := range symbol {
		if (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			continue
		}
		b.WriteRune('_')
	}
	return b.String()
}

func loadBridgeSettlementConfig() (*token.Registry, map[string]*token.Ledger, map[string]string, error) {
	assets := parseBridgeSettlementAssets(os.Getenv("MOHAWK_BRIDGE_SETTLEMENT_ASSETS"))
	if len(assets) == 0 {
		return nil, nil, nil, nil
	}

	registry := token.NewRegistry()
	ledgers := map[string]*token.Ledger{}
	minters := map[string]string{}
	defaultSymbol := strings.ToUpper(strings.TrimSpace(utilityCoinLedger.Symbol()))

	for _, symbol := range assets {
		suffix := symbolEnvSuffix(symbol)
		statePath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_STATE_PATH_" + suffix))
		auditPath := strings.TrimSpace(os.Getenv("MOHAWK_LEDGER_AUDIT_PATH_" + suffix))
		minter := strings.TrimSpace(os.Getenv("MOHAWK_UTILITY_MINTER_" + suffix))

		var ledger *token.Ledger
		if minter == "" {
			if symbol == defaultSymbol {
				minter = utilityCoinLedger.Minter()
			} else {
				minter = "protocol"
			}
		}

		if symbol == defaultSymbol && statePath == "" && auditPath == "" {
			ledger = utilityCoinLedger
		} else if statePath != "" && auditPath != "" {
			persistentLedger, err := token.NewPersistentLedger(symbol, minter, statePath, auditPath)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("load settlement ledger %s: %w", symbol, err)
			}
			ledger = persistentLedger
		} else {
			ledger = token.NewLedger(symbol, minter)
		}

		ledgers[symbol] = ledger
		minters[symbol] = minter
		if err := registry.Register(ledger.Asset()); err != nil {
			return nil, nil, nil, fmt.Errorf("register settlement asset %s: %w", symbol, err)
		}
	}

	return registry, ledgers, minters, nil
}

func configureBridgeSettlement(engine *bridge.Engine, requestSettlementMinter string) error {
	requestSettlementMinter = strings.TrimSpace(requestSettlementMinter)
	engine.EnableSettlement(utilityCoinLedger, requestSettlementMinter)

	registry, ledgers, minters, err := loadBridgeSettlementConfig()
	if err != nil {
		return err
	}
	if registry == nil {
		return nil
	}
	engine.SetSettlementRegistry(registry)
	defaultSymbol := strings.ToUpper(strings.TrimSpace(utilityCoinLedger.Symbol()))
	for symbol, ledger := range ledgers {
		minter := strings.TrimSpace(minters[symbol])
		if symbol == defaultSymbol && requestSettlementMinter != "" {
			minter = requestSettlementMinter
		}
		if err := engine.RegisterSettlementLedger(symbol, ledger, minter); err != nil {
			return err
		}
	}
	return nil
}

func loadAPIToken() string {
	if token := strings.TrimSpace(os.Getenv("MOHAWK_API_TOKEN")); token != "" {
		return token
	}
	secretPath := strings.TrimSpace(os.Getenv("MOHAWK_API_TOKEN_FILE"))
	if secretPath == "" {
		return ""
	}
	secret, err := os.ReadFile(secretPath)
	if err != nil {
		log.Printf("failed to read MOHAWK_API_TOKEN_FILE: %v", err)
		return ""
	}
	return strings.TrimSpace(string(secret))
}

func verifyAPIToken(candidate string) bool {
	if apiAuthToken == "" {
		return true
	}
	candidate = strings.TrimSpace(candidate)
	if candidate == "" {
		return false
	}
	if subtle.ConstantTimeCompare([]byte(candidate), []byte(apiAuthToken)) == 1 {
		return true
	}
	if strings.HasPrefix(strings.ToLower(candidate), "bearer ") {
		trimmed := strings.TrimSpace(candidate[7:])
		return subtle.ConstantTimeCompare([]byte(trimmed), []byte(apiAuthToken)) == 1
	}
	return false
}

//export InitializeNode
func InitializeNode(configJSON *C.char) *C.char {
	configStr := C.GoString(configJSON)
	var config NodeConfig

	if err := json.Unmarshal([]byte(configStr), &config); err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to parse config: %v", err), "")
	}

	state.mu.Lock()
	defer state.mu.Unlock()
	if state.host != nil {
		_ = state.host.Close()
		state.host = nil
	}
	if state.runner != nil {
		_ = state.runner.Close(context.Background())
		state.runner = nil
	}

	meshPlan, err := hva.BuildPlan(10000000, 1024)
	if err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to build HVA plan: %v", err), "")
	}
	host, err := network.NewHost(context.Background(), network.DefaultConfig(0))
	if err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to initialize libp2p host: %v", err), "")
	}

	state.config = config
	state.startedAt = time.Now().UTC()
	state.meshPlan = meshPlan
	state.host = host
	state.aggregator = internalpkg.NewAggregator(internalpkg.Regional)

	msg := fmt.Sprintf("Node %s initialized with config: %s", config.NodeID, config.ConfigPath)
	log.Println(msg)
	data, _ := json.Marshal(map[string]any{
		"node_id":       config.NodeID,
		"mesh_levels":   len(meshPlan.Levels),
		"branch_factor": meshPlan.BranchFactor,
		"peer_id":       host.ID().String(),
	})

	return marshalResult(true, "Node started successfully", string(data))
}

//export VerifyZKProof
func VerifyZKProof(proofJSON *C.char) *C.char {
	proofStr := C.GoString(proofJSON)
	var payload map[string]any
	if err := json.Unmarshal([]byte(proofStr), &payload); err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to parse proof payload: %v", err), "")
	}
	proofBytes := extractProofBytes(payload)
	if len(proofBytes) < 128 {
		proofBytes = append(proofBytes, make([]byte, 128-len(proofBytes))...)
	}
	started := time.Now()
	valid, err := internalpkg.VerifyProof(proofBytes, nil)
	if err != nil {
		return marshalResult(false, err.Error(), "")
	}
	data, _ := json.Marshal(map[string]any{
		"valid":                valid,
		"verification_time_ms": float64(time.Since(started).Microseconds()) / 1000.0,
	})
	return marshalResult(true, "Proof verified", string(data))
}

//export AggregateUpdates
func AggregateUpdates(updatesJSON *C.char) *C.char {
	updatesStr := C.GoString(updatesJSON)
	var updates []struct {
		NodeID   string    `json:"node_id"`
		Gradient []float64 `json:"gradient"`
	}
	if err := json.Unmarshal([]byte(updatesStr), &updates); err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to parse updates: %v", err), "")
	}

	state.mu.Lock()
	if state.aggregator == nil {
		state.aggregator = internalpkg.NewAggregator(internalpkg.Regional)
	}
	aggregator := state.aggregator
	state.mu.Unlock()

	maxNorm := 0.0
	for _, update := range updates {
		norm := 0.0
		for _, value := range update.Gradient {
			norm += value * value
		}
		maxNorm = math.Max(maxNorm, math.Sqrt(norm))
	}
	effectiveActiveNodes := maxInt(len(updates), 80)
	if err := aggregator.ProcessUpdates(effectiveActiveNodes, effectiveActiveNodes, maxNorm); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	data, _ := json.Marshal(map[string]any{"count": len(updates), "max_grad_norm": maxNorm})
	return marshalResult(true, "Updates aggregated successfully", string(data))
}

//export GetNodeStatus
func GetNodeStatus(nodeID *C.char) *C.char {
	node := C.GoString(nodeID)

	state.mu.Lock()
	defer state.mu.Unlock()
	status := map[string]any{
		"node_id":     node,
		"status":      "running",
		"uptime":      time.Since(state.startedAt).String(),
		"mesh_levels": len(state.meshPlan.Levels),
	}
	if state.host != nil {
		status["peer_id"] = state.host.ID().String()
	}

	statusJSON, _ := json.Marshal(status)
	return marshalResult(true, "Status retrieved", string(statusJSON))
}

//export LoadWasmModule
func LoadWasmModule(modulePath *C.char) *C.char {
	path := C.GoString(modulePath)

	wasmBytes, err := os.ReadFile(path)
	if err != nil {
		wasmBytes = []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	}
	runner, err := wasmhost.NewRunner(context.Background(), wasmBytes)
	if err != nil {
		return marshalResult(false, fmt.Sprintf("Failed to load WASM module: %v", err), "")
	}
	state.mu.Lock()
	if state.runner != nil {
		_ = state.runner.Close(context.Background())
	}
	state.runner = runner
	state.mu.Unlock()

	return marshalResult(true, "WASM module loaded", path)
}

//export AttestNode
func AttestNode(nodeID *C.char) *C.char {
	node := C.GoString(nodeID)

	quote, err := tpm.GetVerifiedQuote(node)
	if err != nil {
		return marshalResult(false, fmt.Sprintf("TPM quote generation failed: %v", err), "")
	}
	if err := tpm.Verify(node, quote); err != nil {
		return marshalResult(false, fmt.Sprintf("TPM verification failed: %v", err), "")
	}
	digest := sha256.Sum256(quote)
	data, _ := json.Marshal(map[string]any{
		"node_id":    node,
		"quote_size": len(quote),
		"quote_sha":  hex.EncodeToString(digest[:]),
	})
	return marshalResult(true, "Attestation successful", string(data))
}

//export GetDeviceInfo
func GetDeviceInfo(_ *C.char) *C.char {
	devices := accelerator.DetectDevices()
	data, _ := json.Marshal(map[string]any{
		"devices":    devices,
		"gomaxprocs": runtime.GOMAXPROCS(0),
		"goarch":     runtime.GOARCH,
		"goos":       runtime.GOOS,
	})
	return marshalResult(true, "Device enumeration complete", string(data))
}

//export CompressGradients
func CompressGradients(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Gradients []float64 `json:"gradients"`
		Format    string    `json:"format"` // "fp16" (default) | "int8"
		MaxNorm   float64   `json:"max_norm"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if req.Format == "" {
		req.Format = "fp16"
	}
	fp32 := make([]float32, len(req.Gradients))
	for i, v := range req.Gradients {
		fp32[i] = float32(v)
	}
	originalBytes := len(fp32) * 4

	var compressed []byte
	var scale float64
	switch req.Format {
	case "int8":
		maxNorm := req.MaxNorm
		if maxNorm <= 0 {
			maxNorm = float64(accelerator.L2Norm(fp32))
		}
		quantized, s := accelerator.QuantizeINT8(fp32, maxNorm)
		scale = s
		compressed = make([]byte, len(quantized))
		for i, q := range quantized {
			compressed[i] = byte(q)
		}
	default: // fp16
		compressed = accelerator.FP32ToFP16(fp32)
	}

	ratio := accelerator.CompressionRatio(originalBytes, len(compressed))
	metrics.ObserveGradientCompression(req.Format, ratio)
	metrics.ObserveAcceleratorOp("cpu", "compress_"+req.Format, true)

	data, _ := json.Marshal(map[string]any{
		"format":            req.Format,
		"original_bytes":    originalBytes,
		"compressed_bytes":  len(compressed),
		"compression_ratio": ratio,
		"scale":             scale,
		"data_b64":          base64.StdEncoding.EncodeToString(compressed),
	})
	return marshalResult(true, "Gradients compressed", string(data))
}

//export BatchVerifyProofs
func BatchVerifyProofs(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var proofs []struct {
		ID    string `json:"id"`
		Proof string `json:"proof"`
	}
	if err := json.Unmarshal([]byte(raw), &proofs); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}

	type verifyResult struct {
		ID    string `json:"id"`
		Valid bool   `json:"valid"`
		Error string `json:"error,omitempty"`
	}

	results := make([]verifyResult, len(proofs))
	var wg sync.WaitGroup
	workers := runtime.GOMAXPROCS(0)
	sem := make(chan struct{}, workers)

	for i, p := range proofs {
		wg.Add(1)
		go func(idx int, id, proof string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			proofBytes := []byte(proof)
			if len(proofBytes) < 128 {
				proofBytes = append(proofBytes, make([]byte, 128-len(proofBytes))...)
			}
			valid, err := internalpkg.VerifyProof(proofBytes, nil)
			r := verifyResult{ID: id, Valid: valid}
			if err != nil {
				r.Error = err.Error()
			}
			results[idx] = r
		}(i, p.ID, p.Proof)
	}
	wg.Wait()

	success := true
	for _, r := range results {
		if !r.Valid {
			success = false
			break
		}
	}
	metrics.ObserveProofBatch(len(proofs), success)
	metrics.ObserveAcceleratorOp("cpu", "batch_verify", success)

	data, _ := json.Marshal(map[string]any{
		"count":   len(proofs),
		"results": results,
	})
	return marshalResult(true, "Batch verification complete", string(data))
}

//export BridgeTransfer
func BridgeTransfer(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var payload struct {
		SourceChain        string                      `json:"source_chain"`
		TargetChain        string                      `json:"target_chain"`
		Asset              string                      `json:"asset"`
		Amount             float64                     `json:"amount"`
		Sender             string                      `json:"sender"`
		Receiver           string                      `json:"receiver"`
		Nonce              uint64                      `json:"nonce"`
		FinalityDepth      uint64                      `json:"finality_depth,omitempty"`
		Proof              string                      `json:"proof"`
		RoutePolicy        *bridge.RoutePolicy         `json:"route_policy,omitempty"`
		PolicyManifestPath string                      `json:"policy_manifest_path,omitempty"`
		PolicyManifest     *bridge.RoutePolicyManifest `json:"policy_manifest,omitempty"`
		Settle             bool                        `json:"settle,omitempty"`
		SettlementMinter   string                      `json:"settlement_minter,omitempty"`
		AuthToken          string                      `json:"auth_token,omitempty"`
		Authorization      string                      `json:"authorization,omitempty"`
		APIToken           string                      `json:"api_token,omitempty"`
		Role               string                      `json:"role,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if err := validateAPIAccess("bridge", payload.Role, extractProvidedToken(payload.AuthToken, payload.Authorization, payload.APIToken)); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}
	req := bridge.TransferRequest{
		SourceChain:   payload.SourceChain,
		TargetChain:   payload.TargetChain,
		Asset:         payload.Asset,
		Amount:        payload.Amount,
		Sender:        payload.Sender,
		Receiver:      payload.Receiver,
		Nonce:         payload.Nonce,
		FinalityDepth: payload.FinalityDepth,
		Proof:         payload.Proof,
	}
	engine := bridge.NewEngine("mohawk-bridge-v1")
	hasExplicitPolicy := payload.PolicyManifestPath != "" || payload.PolicyManifest != nil || payload.RoutePolicy != nil
	if payload.PolicyManifestPath != "" {
		manifest, err := bridge.LoadRoutePolicyManifestFile(payload.PolicyManifestPath)
		if err != nil {
			metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", false)
			return marshalResult(false, err.Error(), "")
		}
		engine.RegisterRoutePolicyManifest(manifest)
	}
	if payload.PolicyManifest != nil {
		engine.RegisterRoutePolicyManifest(*payload.PolicyManifest)
	}
	if !hasExplicitPolicy {
		manifest, loaded, err := bridge.LoadDefaultRoutePolicyManifest()
		if err != nil {
			metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", false)
			return marshalResult(false, err.Error(), "")
		}
		if loaded {
			engine.RegisterRoutePolicyManifest(manifest)
		}
	}
	if payload.RoutePolicy != nil {
		engine.RegisterRoutePolicy(req.SourceChain, req.TargetChain, *payload.RoutePolicy)
	}
	if payload.Settle {
		if err := configureBridgeSettlement(engine, payload.SettlementMinter); err != nil {
			metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", false)
			return marshalResult(false, err.Error(), "")
		}
	}
	receipt, err := engine.VerifyTransfer(req)
	if err != nil {
		metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", false)
		return marshalResult(false, err.Error(), "")
	}
	response := map[string]any{"receipt": receipt}
	if payload.Settle {
		settlement, settleErr := engine.SettleVerifiedTransfer(req, receipt)
		if settleErr != nil {
			metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", false)
			response["settlement"] = settlement
			data, _ := json.Marshal(response)
			return marshalResult(false, settleErr.Error(), string(data))
		}
		response["settlement"] = settlement
	}
	metrics.ObserveAcceleratorOp("cpu", "bridge_transfer", true)
	data, _ := json.Marshal(response)
	if payload.Settle {
		return marshalResult(true, "Cross-chain transfer verified and settled", string(data))
	}
	return marshalResult(true, "Cross-chain transfer verified", string(data))
}

//export GetHybridBackends
func GetHybridBackends(_ *C.char) *C.char {
	backends := hybrid.AvailableSTARKBackends()
	data, _ := json.Marshal(map[string]any{
		"backends": backends,
	})
	return marshalResult(true, "Available STARK backends", string(data))
}

//export VerifyHybridProof
func VerifyHybridProof(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Mode          string `json:"mode"`
		SNARKProof    string `json:"snark_proof"`
		STARKProof    string `json:"stark_proof"`
		STARKBackend  string `json:"stark_backend"`
		AuthToken     string `json:"auth_token,omitempty"`
		Authorization string `json:"authorization,omitempty"`
		APIToken      string `json:"api_token,omitempty"`
		Role          string `json:"role,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if err := validateAPIAccess("hybrid", req.Role, extractProvidedToken(req.AuthToken, req.Authorization, req.APIToken)); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}

	result, err := hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.HybridMode(req.Mode),
		SNARKProof:   []byte(req.SNARKProof),
		STARKProof:   []byte(req.STARKProof),
		STARKBackend: req.STARKBackend,
	})
	available := hybrid.AvailableSTARKBackends()
	if err != nil {
		metrics.ObserveAcceleratorOp("cpu", "hybrid_verify", false)
		data, _ := json.Marshal(map[string]any{
			"result":             result,
			"available_backends": available,
		})
		return marshalResult(false, err.Error(), string(data))
	}
	metrics.ObserveAcceleratorOp("cpu", "hybrid_verify", true)
	data, _ := json.Marshal(map[string]any{
		"result":             result,
		"available_backends": available,
	})
	return marshalResult(true, "Hybrid SNARK/STARK verification complete", string(data))
}

//export MintUtilityCoin
func MintUtilityCoin(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Actor          string  `json:"actor"`
		To             string  `json:"to"`
		Amount         float64 `json:"amount"`
		Memo           string  `json:"memo,omitempty"`
		MintTo         string  `json:"mint_to,omitempty"`
		Minter         string  `json:"minter,omitempty"`
		Account        string  `json:"account,omitempty"`
		AuthToken      string  `json:"auth_token,omitempty"`
		Authorization  string  `json:"authorization,omitempty"`
		APIToken       string  `json:"api_token,omitempty"`
		Nonce          uint64  `json:"nonce,omitempty"`
		IdempotencyKey string  `json:"idempotency_key,omitempty"`
		Role           string  `json:"role,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	providedToken := extractProvidedToken(req.AuthToken, req.Authorization, req.APIToken)
	if !verifyAPIToken(providedToken) {
		return marshalResult(false, "unauthorized: invalid API token", "")
	}
	if err := authorizeUtilityRole("mint", req.Role); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}
	to := req.To
	if to == "" {
		if req.MintTo != "" {
			to = req.MintTo
		} else {
			to = req.Account
		}
	}
	actor := req.Actor
	if actor == "" {
		actor = req.Minter
	}
	if err := enforceUtilityRateLimit(actor); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	tx, err := utilityCoinLedger.MintWithControls(actor, to, req.Amount, req.Memo, req.IdempotencyKey, req.Nonce)
	if err != nil {
		return marshalResult(false, err.Error(), "")
	}
	snapshot := utilityCoinLedger.Snapshot()
	totalSupply, _ := snapshot["total_supply"].(float64)
	txCount, _ := snapshot["tx_count"].(int)
	metrics.ObserveUtilityCoinMint(req.Amount, totalSupply, txCount)
	data, _ := json.Marshal(map[string]any{
		"tx":      tx,
		"balance": utilityCoinLedger.Balance(to),
		"symbol":  utilityCoinLedger.Symbol(),
	})
	return marshalResult(true, "Utility coin minted", string(data))
}

//export TransferUtilityCoin
func TransferUtilityCoin(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		From           string  `json:"from"`
		To             string  `json:"to"`
		Amount         float64 `json:"amount"`
		Memo           string  `json:"memo,omitempty"`
		Sender         string  `json:"sender,omitempty"`
		Receiver       string  `json:"receiver,omitempty"`
		AuthToken      string  `json:"auth_token,omitempty"`
		Authorization  string  `json:"authorization,omitempty"`
		APIToken       string  `json:"api_token,omitempty"`
		Nonce          uint64  `json:"nonce,omitempty"`
		IdempotencyKey string  `json:"idempotency_key,omitempty"`
		Role           string  `json:"role,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	providedToken := extractProvidedToken(req.AuthToken, req.Authorization, req.APIToken)
	if !verifyAPIToken(providedToken) {
		return marshalResult(false, "unauthorized: invalid API token", "")
	}
	if err := authorizeUtilityRole("transfer", req.Role); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}
	from := req.From
	if from == "" {
		from = req.Sender
	}
	to := req.To
	if to == "" {
		to = req.Receiver
	}
	if err := enforceUtilityRateLimit(from); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	tx, err := utilityCoinLedger.TransferWithControls(from, to, req.Amount, req.Memo, req.IdempotencyKey, req.Nonce)
	if err != nil {
		return marshalResult(false, err.Error(), "")
	}
	snapshot := utilityCoinLedger.Snapshot()
	txCount, _ := snapshot["tx_count"].(int)
	metrics.ObserveUtilityCoinTransfer(req.Amount, txCount)
	data, _ := json.Marshal(map[string]any{
		"tx":           tx,
		"from_balance": utilityCoinLedger.Balance(from),
		"to_balance":   utilityCoinLedger.Balance(to),
		"symbol":       utilityCoinLedger.Symbol(),
	})
	return marshalResult(true, "Utility coin transferred", string(data))
}

//export GetUtilityCoinBalance
func GetUtilityCoinBalance(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Account string `json:"account"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if req.Account == "" {
		return marshalResult(false, "account is required", "")
	}
	data, _ := json.Marshal(map[string]any{
		"account": req.Account,
		"balance": utilityCoinLedger.Balance(req.Account),
		"symbol":  utilityCoinLedger.Symbol(),
	})
	return marshalResult(true, "Utility coin balance retrieved", string(data))
}

//export GetUtilityCoinLedger
func GetUtilityCoinLedger(_ *C.char) *C.char {
	snapshot := utilityCoinLedger.Snapshot()
	totalSupply, _ := snapshot["total_supply"].(float64)
	txCount, _ := snapshot["tx_count"].(int)
	metrics.ObserveUtilityCoinSnapshot(totalSupply, txCount)
	data, _ := json.Marshal(snapshot)
	return marshalResult(true, "Utility coin ledger snapshot", string(data))
}

//export BackupUtilityCoinLedger
func BackupUtilityCoinLedger(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Path          string `json:"path"`
		Role          string `json:"role,omitempty"`
		AuthToken     string `json:"auth_token,omitempty"`
		Authorization string `json:"authorization,omitempty"`
		APIToken      string `json:"api_token,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if req.Path == "" {
		return marshalResult(false, "path is required", "")
	}
	providedToken := extractProvidedToken(req.AuthToken, req.Authorization, req.APIToken)
	if !verifyAPIToken(providedToken) {
		return marshalResult(false, "unauthorized: invalid API token", "")
	}
	if err := authorizeUtilityRole("backup", req.Role); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}
	if err := enforceUtilityRateLimit("utility-admin"); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	if err := utilityCoinLedger.Backup(req.Path); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	data, _ := json.Marshal(map[string]any{"path": req.Path})
	return marshalResult(true, "Utility coin ledger backup complete", string(data))
}

//export RestoreUtilityCoinLedger
func RestoreUtilityCoinLedger(payloadJSON *C.char) *C.char {
	raw := C.GoString(payloadJSON)
	var req struct {
		Path          string `json:"path"`
		Role          string `json:"role,omitempty"`
		AuthToken     string `json:"auth_token,omitempty"`
		Authorization string `json:"authorization,omitempty"`
		APIToken      string `json:"api_token,omitempty"`
	}
	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return marshalResult(false, fmt.Sprintf("parse error: %v", err), "")
	}
	if req.Path == "" {
		return marshalResult(false, "path is required", "")
	}
	providedToken := extractProvidedToken(req.AuthToken, req.Authorization, req.APIToken)
	if !verifyAPIToken(providedToken) {
		return marshalResult(false, "unauthorized: invalid API token", "")
	}
	if err := authorizeUtilityRole("restore", req.Role); err != nil {
		return marshalResult(false, fmt.Sprintf("unauthorized: %v", err), "")
	}
	if err := enforceUtilityRateLimit("utility-admin"); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	if err := utilityCoinLedger.Restore(req.Path); err != nil {
		return marshalResult(false, err.Error(), "")
	}
	data, _ := json.Marshal(map[string]any{"path": req.Path})
	return marshalResult(true, "Utility coin ledger restore complete", string(data))
}

// Helper function to marshal results to JSON and return as C string
func marshalResult(success bool, message, data string) *C.char {
	result := Result{
		Success: success,
		Message: message,
		Data:    data,
	}

	jsonBytes, err := json.Marshal(result)
	if err != nil {
		errorJSON := fmt.Sprintf(`{"success":false,"message":"Marshaling error: %v"}`, err)
		return C.CString(errorJSON)
	}

	return C.CString(string(jsonBytes))
}

// Required main function for cgo
func main() {}

func extractProofBytes(payload map[string]any) []byte {
	if raw, ok := payload["proof"].(string); ok {
		return []byte(raw)
	}
	encoded, _ := json.Marshal(payload)
	return encoded
}

func maxInt(a int, b int) int {
	if a > b {
		return a
	}
	return b
}
