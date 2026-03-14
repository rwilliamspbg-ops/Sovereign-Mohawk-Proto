package bridge

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// TransferRequest defines a chain-agnostic cross-chain transfer envelope.
type TransferRequest struct {
	SourceChain   string  `json:"source_chain"`
	TargetChain   string  `json:"target_chain"`
	Asset         string  `json:"asset"`
	Amount        float64 `json:"amount"`
	Sender        string  `json:"sender"`
	Receiver      string  `json:"receiver"`
	Nonce         uint64  `json:"nonce"`
	FinalityDepth uint64  `json:"finality_depth,omitempty"`
	Proof         string  `json:"proof"`
}

// Receipt is an immutable bridge receipt for transfer verification.
type Receipt struct {
	BridgeID      string `json:"bridge_id"`
	SourceChain   string `json:"source_chain"`
	TargetChain   string `json:"target_chain"`
	SourceAdapter string `json:"source_adapter"`
	TargetAdapter string `json:"target_adapter"`
	Asset         string `json:"asset"`
	Amount        string `json:"amount"`
	Nonce         uint64 `json:"nonce"`
	FinalityDepth uint64 `json:"finality_depth,omitempty"`
	RoutePolicyID string `json:"route_policy_id,omitempty"`
	ProofRoot     string `json:"proof_root"`
	IssuedAtMS    int64  `json:"issued_at_ms"`
}

// Engine performs deterministic cross-chain envelope verification.
type Engine struct {
	BridgeID string
	adapters map[string]Adapter
	policies map[string]RoutePolicy
}

// NewEngine creates a bridge engine with a stable ID.
func NewEngine(id string) *Engine {
	if id == "" {
		id = "mohawk-bridge-v1"
	}
	engine := &Engine{
		BridgeID: id,
		adapters: map[string]Adapter{},
		policies: map[string]RoutePolicy{},
	}
	engine.registerDefaults()
	return engine
}

func (e *Engine) registerDefaults() {
	for _, chain := range []string{"ethereum", "polygon", "bsc", "arbitrum", "optimism", "base", "avalanche"} {
		e.adapters[chain] = evmAdapter{}
	}
	for _, chain := range []string{"cosmos", "osmosis", "juno"} {
		e.adapters[chain] = cosmosAdapter{}
	}
	for _, chain := range []string{"polkadot", "kusama"} {
		e.adapters[chain] = substrateAdapter{}
	}
}

// RegisterAdapter binds a specific chain name to a custom adapter.
func (e *Engine) RegisterAdapter(chain string, adapter Adapter) {
	if e.adapters == nil {
		e.adapters = map[string]Adapter{}
	}
	e.adapters[normalizeChain(chain)] = adapter
}

func (e *Engine) resolveAdapter(chain string) Adapter {
	if e.adapters == nil {
		return genericAdapter{}
	}
	if adapter, ok := e.adapters[normalizeChain(chain)]; ok {
		return adapter
	}
	return genericAdapter{}
}

// VerifyTransfer validates a transfer request and generates a deterministic receipt.
func (e *Engine) VerifyTransfer(req TransferRequest) (Receipt, error) {
	if req.SourceChain == "" || req.TargetChain == "" {
		return Receipt{}, fmt.Errorf("source_chain and target_chain are required")
	}
	if req.SourceChain == req.TargetChain {
		return Receipt{}, fmt.Errorf("source_chain and target_chain must differ")
	}
	if req.Asset == "" {
		return Receipt{}, fmt.Errorf("asset is required")
	}
	if req.Amount <= 0 {
		return Receipt{}, fmt.Errorf("amount must be > 0")
	}
	if req.Sender == "" || req.Receiver == "" {
		return Receipt{}, fmt.Errorf("sender and receiver are required")
	}
	if req.Proof == "" {
		return Receipt{}, fmt.Errorf("proof is required")
	}

	routePolicy, hasRoutePolicy := e.resolveRoutePolicy(req.SourceChain, req.TargetChain)
	if hasRoutePolicy {
		if err := applyRoutePolicy(req, routePolicy); err != nil {
			return Receipt{}, err
		}
	}

	sourceAdapter := e.resolveAdapter(req.SourceChain)
	targetAdapter := e.resolveAdapter(req.TargetChain)
	if err := sourceAdapter.Verify(req); err != nil {
		return Receipt{}, fmt.Errorf("source adapter (%s) verification failed: %w", sourceAdapter.Name(), err)
	}
	if err := targetAdapter.Verify(req); err != nil {
		return Receipt{}, fmt.Errorf("target adapter (%s) verification failed: %w", targetAdapter.Name(), err)
	}

	payload, _ := json.Marshal(map[string]any{
		"request":        req,
		"source_adapter": sourceAdapter.Name(),
		"target_adapter": targetAdapter.Name(),
	})
	h := sha256.Sum256(payload)

	receipt := Receipt{
		BridgeID:      e.BridgeID,
		SourceChain:   req.SourceChain,
		TargetChain:   req.TargetChain,
		SourceAdapter: sourceAdapter.Name(),
		TargetAdapter: targetAdapter.Name(),
		Asset:         req.Asset,
		Amount:        fmt.Sprintf("%.8f", req.Amount),
		Nonce:         req.Nonce,
		FinalityDepth: req.FinalityDepth,
		ProofRoot:     hex.EncodeToString(h[:]),
		IssuedAtMS:    time.Now().UnixMilli(),
	}
	if hasRoutePolicy {
		receipt.RoutePolicyID = routePolicy.ID
	}
	return receipt, nil
}

// VerifyReceipt replays receipt hashing to validate determinism.
func (e *Engine) VerifyReceipt(req TransferRequest, receipt Receipt) error {
	recomputed, err := e.VerifyTransfer(req)
	if err != nil {
		return err
	}
	if receipt.BridgeID != e.BridgeID {
		return fmt.Errorf("unexpected bridge id: %s", receipt.BridgeID)
	}
	if strings.TrimSpace(receipt.SourceAdapter) == "" || strings.TrimSpace(receipt.TargetAdapter) == "" {
		return fmt.Errorf("receipt missing adapter metadata")
	}
	if recomputed.ProofRoot != receipt.ProofRoot {
		return fmt.Errorf("receipt proof root mismatch")
	}
	return nil
}
