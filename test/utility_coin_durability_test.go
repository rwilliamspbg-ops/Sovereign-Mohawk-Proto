package test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

func TestUtilityCoinPersistentLedgerRestore(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "ledger_state.json")
	auditPath := filepath.Join(tmp, "ledger_audit.jsonl")

	ledger, err := token.NewPersistentLedger("MHC", "protocol", statePath, auditPath)
	if err != nil {
		t.Fatalf("failed to create persistent ledger: %v", err)
	}
	if _, err := ledger.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	if _, err := ledger.Transfer("edge-a", "edge-b", 3, "settlement"); err != nil {
		t.Fatalf("transfer failed: %v", err)
	}

	reloaded, err := token.NewPersistentLedger("MHC", "protocol", statePath, auditPath)
	if err != nil {
		t.Fatalf("failed to reload persistent ledger: %v", err)
	}
	if got := reloaded.Balance("edge-a"); got != 7 {
		t.Fatalf("unexpected edge-a balance after reload: %.4f", got)
	}
	if got := reloaded.Balance("edge-b"); got != 3 {
		t.Fatalf("unexpected edge-b balance after reload: %.4f", got)
	}

	backupPath := filepath.Join(tmp, "ledger_backup.json")
	if err := reloaded.Backup(backupPath); err != nil {
		t.Fatalf("backup failed: %v", err)
	}

	restored, err := token.NewPersistentLedger("MHC", "protocol", filepath.Join(tmp, "state_restored.json"), filepath.Join(tmp, "audit_restored.jsonl"))
	if err != nil {
		t.Fatalf("failed to create restore target ledger: %v", err)
	}
	if err := restored.Restore(backupPath); err != nil {
		t.Fatalf("restore failed: %v", err)
	}
	if got := restored.Balance("edge-a"); got != 7 {
		t.Fatalf("unexpected edge-a balance after restore: %.4f", got)
	}
	if got := restored.Balance("edge-b"); got != 3 {
		t.Fatalf("unexpected edge-b balance after restore: %.4f", got)
	}
}

func TestUtilityCoinIdempotencyAndNonceReplay(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")

	mint1, err := ledger.MintWithControls("protocol", "edge-a", 4, "seed", "mint-1", 1)
	if err != nil {
		t.Fatalf("mint with controls failed: %v", err)
	}
	mint2, err := ledger.MintWithControls("protocol", "edge-a", 999, "duplicate", "mint-1", 1)
	if err != nil {
		t.Fatalf("idempotent mint should return original tx: %v", err)
	}
	if mint1.Timestamp != mint2.Timestamp || mint1.Amount != mint2.Amount {
		t.Fatal("idempotent mint did not return original transaction")
	}
	if got := ledger.Balance("edge-a"); got != 4 {
		t.Fatalf("unexpected balance after idempotent mint: %.4f", got)
	}

	if _, err := ledger.TransferWithControls("edge-a", "edge-b", 2, "pay", "tx-1", 2); err != nil {
		t.Fatalf("transfer with controls failed: %v", err)
	}
	if _, err := ledger.TransferWithControls("edge-a", "edge-b", 2, "replay", "tx-2", 2); err == nil {
		t.Fatal("expected nonce replay to fail")
	}
}

func TestUtilityCoinBaseUnitSnapshot(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")

	if _, err := ledger.Mint("protocol", "edge-a", 1.25, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	if got := ledger.BalanceUnits("edge-a"); got != 1250000 {
		t.Fatalf("unexpected base-unit balance: %d", got)
	}

	snapshot := ledger.Snapshot()
	if got, ok := snapshot["total_supply_units"].(int64); !ok || got != 1250000 {
		t.Fatalf("unexpected total_supply_units snapshot value: %#v", snapshot["total_supply_units"])
	}
	balancesUnits, ok := snapshot["balances_units"].(map[string]int64)
	if !ok {
		t.Fatalf("unexpected balances_units snapshot type: %T", snapshot["balances_units"])
	}
	if got := balancesUnits["edge-a"]; got != 1250000 {
		t.Fatalf("unexpected snapshot base-unit balance: %d", got)
	}
	asset, ok := snapshot["asset"].(token.Asset)
	if !ok {
		t.Fatalf("unexpected asset snapshot type: %T", snapshot["asset"])
	}
	if asset.Symbol != "MHC" || asset.Decimals != 6 {
		t.Fatalf("unexpected asset metadata: %+v", asset)
	}
}

func TestUtilityCoinLegacyFloatStateMigration(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "legacy_state.json")
	auditPath := filepath.Join(tmp, "legacy_audit.jsonl")

	legacyState := map[string]any{
		"schema_version": 1,
		"symbol":         "MHC",
		"minter":         "protocol",
		"balances": map[string]float64{
			"edge-a": 7.5,
			"edge-b": 2.25,
		},
		"txns": []map[string]any{
			{
				"type":      "mint",
				"to":        "edge-a",
				"amount":    7.5,
				"timestamp": "2025-01-01T00:00:00Z",
			},
		},
		"total_supply": 9.75,
	}
	raw, err := json.Marshal(legacyState)
	if err != nil {
		t.Fatalf("marshal legacy state: %v", err)
	}
	if err := os.WriteFile(statePath, raw, 0o600); err != nil {
		t.Fatalf("write legacy state: %v", err)
	}

	ledger, err := token.NewPersistentLedger("MHC", "protocol", statePath, auditPath)
	if err != nil {
		t.Fatalf("load legacy ledger: %v", err)
	}
	if got := ledger.BalanceUnits("edge-a"); got != 7500000 {
		t.Fatalf("unexpected migrated edge-a units: %d", got)
	}
	if got := ledger.BalanceUnits("edge-b"); got != 2250000 {
		t.Fatalf("unexpected migrated edge-b units: %d", got)
	}
	if got := ledger.Balance("edge-a"); got != 7.5 {
		t.Fatalf("unexpected migrated edge-a balance: %.4f", got)
	}

	backupPath := filepath.Join(tmp, "migrated_state.json")
	if err := ledger.Backup(backupPath); err != nil {
		t.Fatalf("backup migrated ledger: %v", err)
	}
	backupRaw, err := os.ReadFile(backupPath)
	if err != nil {
		t.Fatalf("read migrated backup: %v", err)
	}
	var migrated struct {
		SchemaVersion    int              `json:"schema_version"`
		BalancesUnits    map[string]int64 `json:"balances_units"`
		TotalSupplyUnits int64            `json:"total_supply_units"`
	}
	if err := json.Unmarshal(backupRaw, &migrated); err != nil {
		t.Fatalf("parse migrated backup: %v", err)
	}
	if migrated.SchemaVersion != 2 {
		t.Fatalf("unexpected migrated schema version: %d", migrated.SchemaVersion)
	}
	if got := migrated.BalancesUnits["edge-a"]; got != 7500000 {
		t.Fatalf("unexpected persisted migrated edge-a units: %d", got)
	}
	if migrated.TotalSupplyUnits != 9750000 {
		t.Fatalf("unexpected persisted total supply units: %d", migrated.TotalSupplyUnits)
	}
}

func TestUtilityAssetRegistry(t *testing.T) {
	registry := token.NewRegistryWithDefaults()
	mhc, ok := registry.Get("mhc")
	if !ok {
		t.Fatal("expected default MHC asset")
	}
	if mhc.Decimals != 6 {
		t.Fatalf("unexpected default decimals: %d", mhc.Decimals)
	}

	if err := registry.Register(token.Asset{Symbol: "USDX", Decimals: 2, MaxSupplyUnits: 100000000}); err != nil {
		t.Fatalf("register asset failed: %v", err)
	}
	usdx, ok := registry.Get("usdx")
	if !ok {
		t.Fatal("expected USDX asset")
	}
	if usdx.MaxSupplyUnits != 100000000 {
		t.Fatalf("unexpected max supply units: %d", usdx.MaxSupplyUnits)
	}
	items := registry.List()
	if len(items) < 2 {
		t.Fatalf("expected at least 2 assets, got %d", len(items))
	}
}
