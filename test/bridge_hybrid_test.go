package test

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/bridge"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/hybrid"
	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

func TestBridgeTransfer(t *testing.T) {
	engine := bridge.NewEngine("test-bridge")
	req := bridge.TransferRequest{
		SourceChain: "ethereum",
		TargetChain: "polygon",
		Asset:       "USDC",
		Amount:      42.5,
		Sender:      "0xabc",
		Receiver:    "0xdef",
		Nonce:       7,
		Proof:       "proof-bytes",
	}
	receipt, err := engine.VerifyTransfer(req)
	if err != nil {
		t.Fatalf("VerifyTransfer failed: %v", err)
	}
	if receipt.SourceChain != "ethereum" || receipt.TargetChain != "polygon" {
		t.Fatalf("unexpected receipt chains: %+v", receipt)
	}
	if receipt.SourceAdapter == "" || receipt.TargetAdapter == "" {
		t.Fatalf("expected adapter metadata in receipt: %+v", receipt)
	}
	if err := engine.VerifyReceipt(req, receipt); err != nil {
		t.Fatalf("VerifyReceipt failed: %v", err)
	}
}

func TestBridgePolicyManifest(t *testing.T) {
	engine := bridge.NewEngine("test-bridge")
	manifest := bridge.RoutePolicyManifest{
		Version: "v1",
		Routes: []bridge.RoutePolicyRoute{
			{
				SourceChain: "ethereum",
				TargetChain: "polygon",
				Policy: bridge.RoutePolicy{
					ID:                "evm-usdc-fast",
					AllowedAssets:     []string{"USDC"},
					MinAmount:         1,
					MaxAmount:         100,
					MinFinalityBlocks: 12,
				},
			},
		},
	}
	engine.RegisterRoutePolicyManifest(manifest)
	if _, err := engine.VerifyTransfer(bridge.TransferRequest{
		SourceChain:   "ethereum",
		TargetChain:   "polygon",
		Asset:         "USDC",
		Amount:        10,
		Sender:        "0xabc",
		Receiver:      "0xdef",
		Nonce:         1,
		FinalityDepth: 12,
		Proof:         "proof-bytes",
	}); err != nil {
		t.Fatalf("manifest policy should allow transfer: %v", err)
	}

	raw, _ := json.Marshal(manifest)
	tmp, err := os.CreateTemp("", "mohawk-policy-*.json")
	if err != nil {
		t.Fatalf("CreateTemp: %v", err)
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(raw); err != nil {
		t.Fatalf("write manifest: %v", err)
	}
	_ = tmp.Close()
	loaded, err := bridge.LoadRoutePolicyManifestFile(tmp.Name())
	if err != nil {
		t.Fatalf("LoadRoutePolicyManifestFile: %v", err)
	}
	if len(loaded.Routes) != 1 {
		t.Fatalf("expected 1 route in loaded manifest, got %d", len(loaded.Routes))
	}
}

func TestDefaultBridgePolicyManifestLoad(t *testing.T) {
	manifest := bridge.RoutePolicyManifest{
		Version: "v1",
		Routes: []bridge.RoutePolicyRoute{
			{
				SourceChain: "ethereum",
				TargetChain: "polygon",
				Policy: bridge.RoutePolicy{
					ID:                "default-evm-usdc",
					AllowedAssets:     []string{"USDC"},
					MinAmount:         1,
					MaxAmount:         500,
					MinFinalityBlocks: 12,
				},
			},
		},
	}
	raw, _ := json.Marshal(manifest)
	tmp, err := os.CreateTemp("", "mohawk-default-policy-*.json")
	if err != nil {
		t.Fatalf("CreateTemp: %v", err)
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(raw); err != nil {
		t.Fatalf("write manifest: %v", err)
	}
	_ = tmp.Close()

	t.Setenv(bridge.PolicyManifestPathEnv, tmp.Name())
	loaded, ok, err := bridge.LoadDefaultRoutePolicyManifest()
	if err != nil {
		t.Fatalf("LoadDefaultRoutePolicyManifest: %v", err)
	}
	if !ok {
		t.Fatal("expected default manifest to be loaded")
	}
	if len(loaded.Routes) != 1 || loaded.Routes[0].Policy.ID != "default-evm-usdc" {
		t.Fatalf("unexpected loaded manifest: %+v", loaded)
	}
}

func TestBridgeTransferTypedProofs(t *testing.T) {
	engine := bridge.NewEngine("test-bridge")

	evmProof, _ := json.Marshal(map[string]any{
		"block_hash":   "0xabc",
		"tx_hash":      "0xdef",
		"log_index":    1,
		"event_sig":    "Transfer(address,address,uint256)",
		"receipt_root": "0x123",
	})
	reqEVM := bridge.TransferRequest{
		SourceChain: "ethereum",
		TargetChain: "polygon",
		Asset:       "USDC",
		Amount:      1.0,
		Sender:      "0xabc",
		Receiver:    "0xdef",
		Nonce:       1,
		Proof:       string(evmProof),
	}
	if _, err := engine.VerifyTransfer(reqEVM); err != nil {
		t.Fatalf("typed evm proof should verify: %v", err)
	}

	cosmosProof, _ := json.Marshal(map[string]any{
		"client_id":     "07-tendermint-0",
		"connection_id": "connection-0",
		"channel_id":    "channel-0",
		"port_id":       "transfer",
		"sequence":      42,
		"commitment":    "abc123",
		"height":        12345,
	})
	reqCosmos := bridge.TransferRequest{
		SourceChain: "cosmos",
		TargetChain: "ethereum",
		Asset:       "ATOM",
		Amount:      2.0,
		Sender:      "cosmos1sender",
		Receiver:    "0xdef",
		Nonce:       2,
		Proof:       string(cosmosProof),
	}
	if _, err := engine.VerifyTransfer(reqCosmos); err != nil {
		t.Fatalf("typed cosmos proof should verify: %v", err)
	}
}

func TestBridgeRoutePolicy(t *testing.T) {
	engine := bridge.NewEngine("test-bridge")
	engine.RegisterRoutePolicy("ethereum", "polygon", bridge.RoutePolicy{
		ID:                "evm-usdc-fast-finality",
		AllowedAssets:     []string{"USDC", "USDT"},
		MinAmount:         1.0,
		MaxAmount:         1000.0,
		MinFinalityBlocks: 12,
	})
	req := bridge.TransferRequest{
		SourceChain:   "ethereum",
		TargetChain:   "polygon",
		Asset:         "USDC",
		Amount:        10.0,
		Sender:        "0xabc",
		Receiver:      "0xdef",
		Nonce:         9,
		FinalityDepth: 12,
		Proof:         "proof-bytes",
	}
	receipt, err := engine.VerifyTransfer(req)
	if err != nil {
		t.Fatalf("route policy compatible transfer should pass: %v", err)
	}
	if receipt.RoutePolicyID != "evm-usdc-fast-finality" {
		t.Fatalf("expected policy id in receipt, got %q", receipt.RoutePolicyID)
	}

	req.Asset = "DAI"
	if _, err := engine.VerifyTransfer(req); err == nil {
		t.Fatal("expected policy asset rejection")
	}
}

func TestBridgeSettlementSuccess(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "0xaaa", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}

	engine := bridge.NewEngine("test-bridge")
	engine.EnableSettlement(ledger, "protocol")
	record, err := engine.SettleTransfer(bridge.TransferRequest{
		SourceChain: "ethereum",
		TargetChain: "polygon",
		Asset:       "MHC",
		Amount:      3,
		Sender:      "0xaaa",
		Receiver:    "0xbbb",
		Nonce:       11,
		Proof:       "proof-bytes",
	})
	if err != nil {
		t.Fatalf("settlement failed: %v", err)
	}
	if record.Status != "completed" {
		t.Fatalf("unexpected settlement status: %s", record.Status)
	}
	if got := ledger.Balance("0xaaa"); got != 7 {
		t.Fatalf("unexpected sender balance after settlement: %.4f", got)
	}
	if got := ledger.Balance("0xbbb"); got != 3 {
		t.Fatalf("unexpected receiver balance after settlement: %.4f", got)
	}
	if record.BurnTx == nil || record.MintTx == nil {
		t.Fatal("expected burn and mint txs in settlement record")
	}
}

func TestBridgeSettlementRefundFallback(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "0xabc", 9, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if err := ledger.SetAssetPolicy(token.Asset{Symbol: "MHC", Decimals: 6, MaxSupplyUnits: 9000000}); err != nil {
		t.Fatalf("set asset policy failed: %v", err)
	}

	engine := bridge.NewEngine("test-bridge")
	engine.EnableSettlement(ledger, "attacker")
	record, err := engine.SettleTransfer(bridge.TransferRequest{
		SourceChain: "ethereum",
		TargetChain: "polygon",
		Asset:       "MHC",
		Amount:      2,
		Sender:      "0xabc",
		Receiver:    "0xdef",
		Nonce:       12,
		Proof:       "proof-bytes",
	})
	if err == nil {
		t.Fatal("expected settlement to fail when custom minter is unauthorized")
	}
	if record.Status != "refunded" {
		t.Fatalf("expected refunded status, got %s", record.Status)
	}
	if record.RefundTx == nil {
		t.Fatal("expected refund tx in settlement record")
	}
	if got := ledger.Balance("0xabc"); got != 9 {
		t.Fatalf("unexpected sender balance after refund: %.4f", got)
	}
	if got := ledger.Balance("0xdef"); got != 0 {
		t.Fatalf("unexpected receiver balance after failed settlement: %.4f", got)
	}
}

func TestBridgeSettlementMultiAssetRouting(t *testing.T) {
	mhcLedger := token.NewLedger("MHC", "protocol")
	usdxLedger := token.NewLedger("USDX", "protocol")
	if _, err := usdxLedger.Mint("protocol", "cosmos1alice", 8, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}

	registry := token.NewRegistryWithDefaults()
	if err := registry.Register(token.Asset{Symbol: "USDX", Decimals: 6}); err != nil {
		t.Fatalf("register usdx asset failed: %v", err)
	}

	engine := bridge.NewEngine("test-bridge")
	engine.SetSettlementRegistry(registry)
	if err := engine.RegisterSettlementLedger("MHC", mhcLedger, "protocol"); err != nil {
		t.Fatalf("register MHC ledger failed: %v", err)
	}
	if err := engine.RegisterSettlementLedger("USDX", usdxLedger, "protocol"); err != nil {
		t.Fatalf("register USDX ledger failed: %v", err)
	}

	record, err := engine.SettleTransfer(bridge.TransferRequest{
		SourceChain: "cosmos",
		TargetChain: "ethereum",
		Asset:       "USDX",
		Amount:      3,
		Sender:      "cosmos1alice",
		Receiver:    "0xreceiver",
		Nonce:       21,
		Proof:       "proof-bytes",
	})
	if err != nil {
		t.Fatalf("multi-asset settlement failed: %v", err)
	}
	if record.Status != "completed" {
		t.Fatalf("unexpected settlement status: %s", record.Status)
	}
	if got := usdxLedger.Balance("cosmos1alice"); got != 5 {
		t.Fatalf("unexpected usdx sender balance: %.4f", got)
	}
	if got := usdxLedger.Balance("0xreceiver"); got != 3 {
		t.Fatalf("unexpected usdx receiver balance: %.4f", got)
	}
	if got := mhcLedger.Balance("0xreceiver"); got != 0 {
		t.Fatalf("unexpected mhc receiver balance: %.4f", got)
	}
}

func TestBridgeSettlementRegistryRejectsUnknownAsset(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "0xsender", 4, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}

	registry := token.NewRegistryWithDefaults()
	engine := bridge.NewEngine("test-bridge")
	engine.SetSettlementRegistry(registry)
	if err := engine.RegisterSettlementLedger("MHC", ledger, "protocol"); err != nil {
		t.Fatalf("register settlement ledger failed: %v", err)
	}

	if _, err := engine.SettleTransfer(bridge.TransferRequest{
		SourceChain: "ethereum",
		TargetChain: "polygon",
		Asset:       "USDX",
		Amount:      1,
		Sender:      "0xsender",
		Receiver:    "0xreceiver",
		Nonce:       22,
		Proof:       "proof-bytes",
	}); err == nil {
		t.Fatal("expected unknown asset settlement to fail")
	}
}

func TestHybridVerifyModes(t *testing.T) {
	validSNARK := make([]byte, 128)
	validSTARK := make([]byte, 64)

	both, err := hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.ModeBoth,
		SNARKProof:   validSNARK,
		STARKProof:   validSTARK,
		STARKBackend: "simulated_fri",
	})
	if err != nil {
		t.Fatalf("ModeBoth should pass: %v", err)
	}
	if !both.Accepted {
		t.Fatal("expected hybrid acceptance in ModeBoth")
	}
	if both.STARKBackend != "simulated_fri" {
		t.Fatalf("expected simulated_fri backend, got %q", both.STARKBackend)
	}

	_, err = hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.ModeBoth,
		SNARKProof:   nil,
		STARKProof:   validSTARK,
		STARKBackend: "simulated_fri",
	})
	if err == nil {
		t.Fatal("expected failure when one proof fails in ModeBoth")
	}

	any, err := hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.ModeAny,
		SNARKProof:   []byte("short"),
		STARKProof:   validSTARK,
		STARKBackend: "simulated_fri",
	})
	if err != nil {
		t.Fatalf("ModeAny should pass with STARK valid: %v", err)
	}
	if !any.Accepted {
		t.Fatal("expected ModeAny acceptance")
	}

	if _, err := hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.ModeAny,
		SNARKProof:   validSNARK,
		STARKProof:   validSTARK,
		STARKBackend: "unknown_backend",
	}); err == nil {
		t.Fatal("expected unknown backend error")
	}

	backends := hybrid.AvailableSTARKBackends()
	if len(backends) < 2 {
		t.Fatalf("expected at least two STARK backends, got %v", backends)
	}

	winterfell, err := hybrid.VerifyHybrid(hybrid.VerifyRequest{
		Mode:         hybrid.ModeAny,
		SNARKProof:   []byte("short"),
		STARKProof:   make([]byte, 96),
		STARKBackend: "winterfell_mock",
	})
	if err != nil {
		t.Fatalf("winterfell backend should verify: %v", err)
	}
	if !winterfell.Accepted || winterfell.STARKBackend != "winterfell_mock" {
		t.Fatalf("unexpected winterfell result: %+v", winterfell)
	}
}
