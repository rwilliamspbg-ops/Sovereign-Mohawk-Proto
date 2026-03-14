package bridge

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
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

// SettlementRecord captures the bridge-to-ledger settlement lifecycle.
type SettlementRecord struct {
	Receipt      Receipt   `json:"receipt"`
	Status       string    `json:"status"`
	BurnTx       *token.Tx `json:"burn_tx,omitempty"`
	MintTx       *token.Tx `json:"mint_tx,omitempty"`
	RefundTx     *token.Tx `json:"refund_tx,omitempty"`
	Failure      string    `json:"failure,omitempty"`
	SettledAtMS  int64     `json:"settled_at_ms"`
	SettlementID string    `json:"settlement_id"`
}

// Engine performs deterministic cross-chain envelope verification.
type Engine struct {
	BridgeID string
	adapters map[string]Adapter
	policies map[string]RoutePolicy

	settlementMu       sync.RWMutex
	settlementLedger   *token.Ledger
	settlementMinter   string
	settlementRegistry *token.Registry
	settlementLedgers  map[string]*token.Ledger
	settlementMinters  map[string]string
	settlementRecords  map[string]SettlementRecord
}

// NewEngine creates a bridge engine with a stable ID.
func NewEngine(id string) *Engine {
	if id == "" {
		id = "mohawk-bridge-v1"
	}
	engine := &Engine{
		BridgeID:          id,
		adapters:          map[string]Adapter{},
		policies:          map[string]RoutePolicy{},
		settlementLedgers: map[string]*token.Ledger{},
		settlementMinters: map[string]string{},
		settlementRecords: map[string]SettlementRecord{},
	}
	engine.registerDefaults()
	return engine
}

// EnableSettlement configures optional bridge settlement against a utility ledger.
func (e *Engine) EnableSettlement(ledger *token.Ledger, settlementMinter string) {
	e.settlementMu.Lock()
	defer e.settlementMu.Unlock()
	e.settlementLedger = ledger
	if strings.TrimSpace(settlementMinter) == "" && ledger != nil {
		settlementMinter = ledger.Minter()
	}
	e.settlementMinter = strings.TrimSpace(settlementMinter)
	if ledger != nil {
		symbol := normalizeAssetSymbol(ledger.Symbol())
		e.settlementLedgers[symbol] = ledger
		e.settlementMinters[symbol] = e.settlementMinter
	}
}

// SetSettlementRegistry enforces that only registered assets can be settled.
func (e *Engine) SetSettlementRegistry(registry *token.Registry) {
	e.settlementMu.Lock()
	defer e.settlementMu.Unlock()
	e.settlementRegistry = registry
}

// RegisterSettlementLedger binds an asset symbol to a specific settlement ledger and minter.
func (e *Engine) RegisterSettlementLedger(assetSymbol string, ledger *token.Ledger, settlementMinter string) error {
	if ledger == nil {
		return fmt.Errorf("settlement ledger is required")
	}
	symbol := normalizeAssetSymbol(assetSymbol)
	if symbol == "" {
		symbol = normalizeAssetSymbol(ledger.Symbol())
	}
	if symbol == "" {
		return fmt.Errorf("asset symbol is required")
	}
	if strings.TrimSpace(settlementMinter) == "" {
		settlementMinter = ledger.Minter()
	}
	e.settlementMu.Lock()
	defer e.settlementMu.Unlock()
	e.settlementLedgers[symbol] = ledger
	e.settlementMinters[symbol] = strings.TrimSpace(settlementMinter)
	return nil
}

// SettlementRecord returns a previously recorded settlement by receipt proof root.
func (e *Engine) SettlementRecord(proofRoot string) (SettlementRecord, bool) {
	proofRoot = strings.TrimSpace(proofRoot)
	e.settlementMu.RLock()
	defer e.settlementMu.RUnlock()
	record, ok := e.settlementRecords[proofRoot]
	return record, ok
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

// SettleTransfer verifies and settles a transfer against the configured ledger.
func (e *Engine) SettleTransfer(req TransferRequest) (SettlementRecord, error) {
	receipt, err := e.VerifyTransfer(req)
	if err != nil {
		return SettlementRecord{}, err
	}
	return e.SettleVerifiedTransfer(req, receipt)
}

// SettleVerifiedTransfer settles a transfer that already has a verified receipt.
func (e *Engine) SettleVerifiedTransfer(req TransferRequest, receipt Receipt) (SettlementRecord, error) {
	if err := e.VerifyReceipt(req, receipt); err != nil {
		return SettlementRecord{}, err
	}

	e.settlementMu.RLock()
	if existing, ok := e.settlementRecords[receipt.ProofRoot]; ok {
		e.settlementMu.RUnlock()
		return existing, nil
	}
	e.settlementMu.RUnlock()

	ledger, settlementMinter, err := e.resolveSettlementContext(req.Asset)
	if err != nil {
		return SettlementRecord{}, err
	}

	settlementID := fmt.Sprintf("%s:%s:%s:%d", normalizeChain(req.SourceChain), normalizeChain(req.TargetChain), strings.TrimSpace(req.Sender), req.Nonce)
	burnTx, err := ledger.BurnWithControls(req.Sender, req.Amount, "bridge settlement burn", "settlement:"+settlementID+":burn", 0)
	if err != nil {
		record := SettlementRecord{
			Receipt:      receipt,
			Status:       "failed",
			Failure:      err.Error(),
			SettledAtMS:  time.Now().UnixMilli(),
			SettlementID: settlementID,
		}
		e.setSettlementRecord(receipt.ProofRoot, record)
		return record, err
	}

	mintTx, mintErr := ledger.MintWithControls(settlementMinter, req.Receiver, req.Amount, "bridge settlement release", "settlement:"+settlementID+":mint", 0)
	if mintErr == nil {
		record := SettlementRecord{
			Receipt:      receipt,
			Status:       "completed",
			BurnTx:       &burnTx,
			MintTx:       &mintTx,
			SettledAtMS:  time.Now().UnixMilli(),
			SettlementID: settlementID,
		}
		e.setSettlementRecord(receipt.ProofRoot, record)
		return record, nil
	}

	refundActor := settlementMinter
	if strings.TrimSpace(refundActor) == "" {
		refundActor = ledger.Minter()
	}
	refundTx, refundErr := ledger.MintWithControls(refundActor, req.Sender, req.Amount, "bridge settlement refund", "settlement:"+settlementID+":refund", 0)
	if refundErr != nil && !strings.EqualFold(refundActor, ledger.Minter()) {
		refundTx, refundErr = ledger.MintWithControls(ledger.Minter(), req.Sender, req.Amount, "bridge settlement refund", "settlement:"+settlementID+":refund-fallback", 0)
	}
	status := "refunded"
	failure := mintErr.Error()
	var refundPtr *token.Tx
	if refundErr != nil {
		status = "failed"
		failure = mintErr.Error() + "; refund failed: " + refundErr.Error()
	} else {
		refundPtr = &refundTx
	}
	record := SettlementRecord{
		Receipt:      receipt,
		Status:       status,
		BurnTx:       &burnTx,
		RefundTx:     refundPtr,
		Failure:      failure,
		SettledAtMS:  time.Now().UnixMilli(),
		SettlementID: settlementID,
	}
	e.setSettlementRecord(receipt.ProofRoot, record)
	return record, fmt.Errorf("settlement mint failed: %w", mintErr)
}

func (e *Engine) resolveSettlementContext(assetSymbol string) (*token.Ledger, string, error) {
	symbol := normalizeAssetSymbol(assetSymbol)
	e.settlementMu.RLock()
	defer e.settlementMu.RUnlock()
	if symbol == "" {
		return nil, "", fmt.Errorf("asset is required for settlement")
	}
	if e.settlementRegistry != nil {
		if _, ok := e.settlementRegistry.Get(symbol); !ok {
			return nil, "", fmt.Errorf("asset %q is not registered for settlement", symbol)
		}
	}
	if ledger, ok := e.settlementLedgers[symbol]; ok && ledger != nil {
		minter := strings.TrimSpace(e.settlementMinters[symbol])
		if minter == "" {
			minter = ledger.Minter()
		}
		return ledger, minter, nil
	}
	if e.settlementLedger != nil && strings.EqualFold(symbol, normalizeAssetSymbol(e.settlementLedger.Symbol())) {
		minter := strings.TrimSpace(e.settlementMinter)
		if minter == "" {
			minter = e.settlementLedger.Minter()
		}
		return e.settlementLedger, minter, nil
	}
	return nil, "", fmt.Errorf("asset %q has no configured settlement ledger", symbol)
}

func normalizeAssetSymbol(symbol string) string {
	return strings.ToUpper(strings.TrimSpace(symbol))
}

func (e *Engine) setSettlementRecord(proofRoot string, record SettlementRecord) {
	proofRoot = strings.TrimSpace(proofRoot)
	e.settlementMu.Lock()
	defer e.settlementMu.Unlock()
	if e.settlementRecords == nil {
		e.settlementRecords = map[string]SettlementRecord{}
	}
	e.settlementRecords[proofRoot] = record
}
