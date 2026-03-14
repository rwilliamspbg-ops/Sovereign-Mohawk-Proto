package test

import (
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
