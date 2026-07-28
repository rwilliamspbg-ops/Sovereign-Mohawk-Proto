package token

import (
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// --- construction ---------------------------------------------------------

func TestNewLedgerDefaultsMinterWhenBlank(t *testing.T) {
	l := NewLedger("mhc", "   ")
	if l.Minter() != "protocol" {
		t.Fatalf("expected default minter %q, got %q", "protocol", l.Minter())
	}
	if l.Symbol() != "MHC" {
		t.Fatalf("expected normalized symbol MHC, got %q", l.Symbol())
	}
	if l.Asset().Decimals != 6 {
		t.Fatalf("expected default decimals 6, got %d", l.Asset().Decimals)
	}
}

func TestNewLedgerDefaultsSymbolWhenBlank(t *testing.T) {
	l := NewLedger("", "protocol")
	if l.Symbol() != "MHC" {
		t.Fatalf("expected fallback symbol MHC for blank input, got %q", l.Symbol())
	}
}

func TestNewPersistentLedgerEmptyStatePathSkipsPersistence(t *testing.T) {
	l, err := NewPersistentLedger("MHC", "protocol", "", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, err := l.Mint("protocol", "edge-a", 5, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	if err := l.Backup(filepath.Join(t.TempDir(), "backup.json")); err == nil {
		t.Fatal("expected backup to fail when persistence is not configured")
	}
}

// --- mint -------------------------------------------------------------------

func TestMintRequiresAuthorizedMinter(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("attacker", "edge-a", 10, "steal"); err == nil {
		t.Fatal("expected unauthorized mint to fail")
	}
	if got := l.Balance("edge-a"); got != 0 {
		t.Fatalf("balance should be unaffected by failed mint, got %v", got)
	}
}

func TestMintRequiresToAccount(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "", 10, "no target"); err == nil {
		t.Fatal("expected mint without a destination account to fail")
	}
}

func TestMintBlankActorDefaultsToMinter(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("", "edge-a", 10, "implicit actor"); err != nil {
		t.Fatalf("expected blank actor to default to configured minter: %v", err)
	}
	if got := l.Balance("edge-a"); got != 10 {
		t.Fatalf("unexpected balance: %v", got)
	}
}

func TestMintAmountValidation(t *testing.T) {
	tests := []struct {
		name   string
		amount float64
	}{
		{"zero", 0},
		{"negative", -5},
		{"nan", math.NaN()},
		{"positive-inf", math.Inf(1)},
		{"negative-inf", math.Inf(-1)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			l := NewLedger("MHC", "protocol")
			if _, err := l.Mint("protocol", "edge-a", tt.amount, "bad amount"); err == nil {
				t.Fatalf("expected amount %v to be rejected", tt.amount)
			}
		})
	}
}

func TestMintMaxSupplyEnforcement(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if err := l.SetAssetPolicy(Asset{Symbol: "MHC", Decimals: 6, MaxSupplyUnits: 1_000_000}); err != nil {
		t.Fatalf("set asset policy: %v", err)
	}
	// Exactly filling the max supply must succeed.
	if _, err := l.Mint("protocol", "edge-a", 1, "fill exactly"); err != nil {
		t.Fatalf("expected mint at max supply to succeed: %v", err)
	}
	// One more unit must be rejected.
	if _, err := l.Mint("protocol", "edge-a", 0.000001, "overflow"); err == nil {
		t.Fatal("expected mint exceeding max supply to fail")
	}
}

func TestMintIdempotencyReturnsOriginalTransaction(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	first, err := l.MintWithControls("protocol", "edge-a", 4, "seed", "key-1", 1)
	if err != nil {
		t.Fatalf("first mint failed: %v", err)
	}
	dup, err := l.MintWithControls("protocol", "edge-a", 999, "different amount, same key", "key-1", 1)
	if err != nil {
		t.Fatalf("idempotent mint should not error: %v", err)
	}
	if first.Timestamp != dup.Timestamp || first.Amount != dup.Amount {
		t.Fatalf("idempotent mint returned a different transaction: %+v vs %+v", first, dup)
	}
	if got := l.Balance("edge-a"); got != 4 {
		t.Fatalf("balance should reflect only the first mint, got %v", got)
	}
}

func TestMintNonceReplayRejected(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.MintWithControls("protocol", "edge-a", 1, "seed", "", 5); err != nil {
		t.Fatalf("mint with nonce 5 failed: %v", err)
	}
	if _, err := l.MintWithControls("protocol", "edge-a", 1, "replay", "", 5); err == nil {
		t.Fatal("expected replay with equal nonce to fail")
	}
	if _, err := l.MintWithControls("protocol", "edge-a", 1, "replay-lower", "", 4); err == nil {
		t.Fatal("expected replay with lower nonce to fail")
	}
	if _, err := l.MintWithControls("protocol", "edge-a", 1, "advance", "", 6); err != nil {
		t.Fatalf("expected higher nonce to succeed: %v", err)
	}
}

// --- transfer ----------------------------------------------------------------

func TestTransferRequiresFromAndTo(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.Transfer("", "edge-b", 1, "missing from"); err == nil {
		t.Fatal("expected transfer without from account to fail")
	}
	if _, err := l.Transfer("edge-a", "", 1, "missing to"); err == nil {
		t.Fatal("expected transfer without to account to fail")
	}
}

func TestTransferInsufficientBalance(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 1, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.Transfer("edge-a", "edge-b", 2, "too much"); err == nil {
		t.Fatal("expected insufficient balance transfer to fail")
	}
	if got := l.Balance("edge-a"); got != 1 {
		t.Fatalf("failed transfer must not mutate balances, got %v", got)
	}
}

func TestTransferIdempotencyAndNonceReplay(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.TransferWithControls("edge-a", "edge-b", 2, "pay", "tx-1", 1); err != nil {
		t.Fatalf("transfer failed: %v", err)
	}
	dup, err := l.TransferWithControls("edge-a", "edge-b", 2, "pay-again", "tx-1", 1)
	if err != nil {
		t.Fatalf("idempotent transfer should not error: %v", err)
	}
	if dup.Memo != "pay" {
		t.Fatalf("expected idempotent replay to return original memo, got %q", dup.Memo)
	}
	if _, err := l.TransferWithControls("edge-a", "edge-b", 1, "replay", "tx-2", 1); err == nil {
		t.Fatal("expected nonce replay to fail")
	}
	if got := l.Balance("edge-a"); got != 8 {
		t.Fatalf("unexpected balance after idempotent/replay attempts: %v", got)
	}
}

// --- burn ----------------------------------------------------------------

func TestBurnRequiresFromAccount(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Burn("", 1, "no source"); err == nil {
		t.Fatal("expected burn without from account to fail")
	}
}

func TestBurnInsufficientBalance(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 1, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.Burn("edge-a", 2, "too much"); err == nil {
		t.Fatal("expected insufficient balance burn to fail")
	}
}

func TestBurnReducesTotalSupply(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.Burn("edge-a", 4, "reclaim"); err != nil {
		t.Fatalf("burn failed: %v", err)
	}
	snap := l.Snapshot()
	if got := snap["total_supply"].(float64); got != 6 {
		t.Fatalf("unexpected total supply after burn: %v", got)
	}
}

func TestBurnNonceReplayAndIdempotency(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	if _, err := l.BurnWithControls("edge-a", 3, "burn", "burn-1", 1); err != nil {
		t.Fatalf("burn failed: %v", err)
	}
	if _, err := l.BurnWithControls("edge-a", 999, "replay-different-amount", "burn-1", 1); err != nil {
		t.Fatalf("idempotent burn should not error: %v", err)
	}
	if got := l.Balance("edge-a"); got != 7 {
		t.Fatalf("unexpected balance after idempotent burn, got %v", got)
	}
	if _, err := l.BurnWithControls("edge-a", 1, "nonce replay", "", 1); err == nil {
		t.Fatal("expected nonce replay to fail")
	}
}

// --- balances / snapshot ----------------------------------------------------

func TestBalanceForUnknownAccountIsZero(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if got := l.Balance("nobody"); got != 0 {
		t.Fatalf("expected zero balance for unknown account, got %v", got)
	}
	if got := l.BalanceUnits("nobody"); got != 0 {
		t.Fatalf("expected zero unit balance for unknown account, got %v", got)
	}
}

func TestSnapshotReflectsState(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 1.25, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	snap := l.Snapshot()
	if got := snap["symbol"].(string); got != "MHC" {
		t.Fatalf("unexpected symbol in snapshot: %v", got)
	}
	if got := snap["tx_count"].(int); got != 1 {
		t.Fatalf("unexpected tx_count: %v", got)
	}
	balances := snap["balances"].(map[string]float64)
	if balances["edge-a"] != 1.25 {
		t.Fatalf("unexpected balance in snapshot: %v", balances["edge-a"])
	}
}

// --- asset policy ----------------------------------------------------------

func TestSetAssetPolicyRequiresSymbol(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if err := l.SetAssetPolicy(Asset{Symbol: "   "}); err == nil {
		t.Fatal("expected empty symbol to be rejected")
	}
}

func TestSetAssetPolicyCannotChangeSymbolWithSupply(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 1, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	if err := l.SetAssetPolicy(Asset{Symbol: "OTHER", Decimals: 6}); err == nil {
		t.Fatal("expected symbol change with non-zero supply to fail")
	}
}

func TestSetAssetPolicyMaxSupplyBelowCurrentSupplyRejected(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	amountUnits, err := l.AmountToUnits(5)
	if err != nil {
		t.Fatalf("amount conversion failed: %v", err)
	}
	if err := l.SetAssetPolicy(Asset{Symbol: "MHC", Decimals: 6, MaxSupplyUnits: amountUnits}); err == nil {
		t.Fatal("expected max supply below current supply to be rejected")
	}
}

func TestSetAssetPolicyZeroDecimalsNormalizesToSix(t *testing.T) {
	// normalizeAsset() treats Decimals == 0 as "unset" and forces it to 6.
	// This means an asset that legitimately wants whole-unit (0-decimal)
	// precision cannot currently be represented. Documented here as a
	// behavior pin, not necessarily desired behavior -- see test report.
	l := NewLedger("MHC", "protocol")
	if err := l.SetAssetPolicy(Asset{Symbol: "WHOLE", Decimals: 0}); err != nil {
		t.Fatalf("set asset policy failed: %v", err)
	}
	if got := l.Asset().Decimals; got != 6 {
		t.Fatalf("expected zero decimals to normalize to 6, got %d", got)
	}
}

// --- unit conversion ---------------------------------------------------------

func TestAmountToUnitsRoundTrip(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if err := l.SetAssetPolicy(Asset{Symbol: "MHC", Decimals: 2}); err != nil {
		t.Fatalf("set asset policy failed: %v", err)
	}
	units, err := l.AmountToUnits(12.34)
	if err != nil {
		t.Fatalf("amount to units failed: %v", err)
	}
	if units != 1234 {
		t.Fatalf("expected 1234 units, got %d", units)
	}
	if got := l.UnitsToAmount(units); got != 12.34 {
		t.Fatalf("round trip mismatch: got %v", got)
	}
}

func TestAmountToUnitsOverflowRejected(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.AmountToUnits(1e18); err == nil {
		t.Fatal("expected an amount exceeding int64 base-unit range to fail")
	}
}

func TestAmountToUnitsNonPositiveRejected(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.AmountToUnits(0); err == nil {
		t.Fatal("expected zero amount to fail")
	}
	if _, err := l.AmountToUnits(-1); err == nil {
		t.Fatal("expected negative amount to fail")
	}
}

// --- backup / restore / load ------------------------------------------------

func TestBackupRestoreRoundTrip(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "state.json")
	auditPath := filepath.Join(tmp, "audit.jsonl")
	l, err := NewPersistentLedger("MHC", "protocol", statePath, auditPath)
	if err != nil {
		t.Fatalf("create persistent ledger: %v", err)
	}
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	backupPath := filepath.Join(tmp, "backup.json")
	if err := l.Backup(backupPath); err != nil {
		t.Fatalf("backup failed: %v", err)
	}

	restoreTarget, err := NewPersistentLedger("MHC", "protocol", filepath.Join(tmp, "restored_state.json"), filepath.Join(tmp, "restored_audit.jsonl"))
	if err != nil {
		t.Fatalf("create restore target: %v", err)
	}
	if _, err := restoreTarget.Mint("protocol", "should-be-overwritten", 999, "will be wiped"); err != nil {
		t.Fatalf("seed mint on restore target failed: %v", err)
	}
	if err := restoreTarget.Restore(backupPath); err != nil {
		t.Fatalf("restore failed: %v", err)
	}
	if got := restoreTarget.Balance("edge-a"); got != 10 {
		t.Fatalf("unexpected balance after restore: %v", got)
	}
	if got := restoreTarget.Balance("should-be-overwritten"); got != 0 {
		t.Fatalf("expected restore to fully replace prior state, got balance %v", got)
	}
}

func TestRestoreNonexistentBackupErrors(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if err := l.Restore(filepath.Join(t.TempDir(), "does-not-exist.json")); err == nil {
		t.Fatal("expected restore of a missing backup file to fail")
	}
}

func TestRestoreMalformedBackupErrors(t *testing.T) {
	tmp := t.TempDir()
	backupPath := filepath.Join(tmp, "bad_backup.json")
	if err := os.WriteFile(backupPath, []byte("{not valid json"), 0o600); err != nil {
		t.Fatalf("write malformed backup: %v", err)
	}
	l := NewLedger("MHC", "protocol")
	if err := l.Restore(backupPath); err == nil {
		t.Fatal("expected restore of malformed JSON to fail")
	}
}

func TestLoadStateCorruptJSONErrors(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "state.json")
	if err := os.WriteFile(statePath, []byte("{corrupt"), 0o600); err != nil {
		t.Fatalf("write corrupt state: %v", err)
	}
	if _, err := NewPersistentLedger("MHC", "protocol", statePath, filepath.Join(tmp, "audit.jsonl")); err == nil {
		t.Fatal("expected loading corrupt state to fail")
	}
}

func TestLoadStateCreatesFileWhenMissing(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "nested", "state.json")
	l, err := NewPersistentLedger("MHC", "protocol", statePath, "")
	if err != nil {
		t.Fatalf("create persistent ledger: %v", err)
	}
	if _, err := os.Stat(statePath); err != nil {
		t.Fatalf("expected state file to be created: %v", err)
	}
	if l.Symbol() != "MHC" {
		t.Fatalf("unexpected symbol: %v", l.Symbol())
	}
}

func TestAuditLogAppendsHashChain(t *testing.T) {
	tmp := t.TempDir()
	statePath := filepath.Join(tmp, "state.json")
	auditPath := filepath.Join(tmp, "audit.jsonl")
	l, err := NewPersistentLedger("MHC", "protocol", statePath, auditPath)
	if err != nil {
		t.Fatalf("create persistent ledger: %v", err)
	}
	if _, err := l.Mint("protocol", "edge-a", 1, "one"); err != nil {
		t.Fatalf("mint 1 failed: %v", err)
	}
	if _, err := l.Mint("protocol", "edge-a", 2, "two"); err != nil {
		t.Fatalf("mint 2 failed: %v", err)
	}
	raw, err := os.ReadFile(auditPath)
	if err != nil {
		t.Fatalf("read audit log: %v", err)
	}
	var records []map[string]any
	for _, line := range splitNonEmptyLines(raw) {
		var rec map[string]any
		if err := json.Unmarshal(line, &rec); err != nil {
			t.Fatalf("parse audit record: %v", err)
		}
		records = append(records, rec)
	}
	if len(records) != 2 {
		t.Fatalf("expected 2 audit records, got %d", len(records))
	}
	if records[1]["prev_hash"] != records[0]["hash"] {
		t.Fatalf("expected audit hash chain to link records: %v != %v", records[1]["prev_hash"], records[0]["hash"])
	}
}

func splitNonEmptyLines(raw []byte) [][]byte {
	var out [][]byte
	start := 0
	for i, b := range raw {
		if b == '\n' {
			if i > start {
				out = append(out, raw[start:i])
			}
			start = i + 1
		}
	}
	if start < len(raw) {
		out = append(out, raw[start:])
	}
	return out
}

// --- migration status --------------------------------------------------------

func TestPQCMigrationStatusEpochActive(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	l.ConfigurePQCMigrationEpoch(time.Now().Add(-time.Minute), true)
	status := l.PQCMigrationStatus()
	if active, ok := status["epoch_active"].(bool); !ok || !active {
		t.Fatalf("expected epoch_active=true for past epoch, got %#v", status["epoch_active"])
	}
}

func TestPQCMigrationStatusEpochNotActiveWhenZero(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	status := l.PQCMigrationStatus()
	if active, ok := status["epoch_active"].(bool); !ok || active {
		t.Fatalf("expected epoch_active=false when epoch unset, got %#v", status["epoch_active"])
	}
}

func TestPQCMigrationStatusFutureEpochNotYetActive(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	l.ConfigurePQCMigrationEpoch(time.Now().Add(time.Hour), true)
	status := l.PQCMigrationStatus()
	if active, ok := status["epoch_active"].(bool); !ok || active {
		t.Fatalf("expected epoch_active=false for future epoch, got %#v", status["epoch_active"])
	}
}

// --- migration transfer edge cases -------------------------------------------

func TestMigrationRequiresDistinctAccounts(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "edge-a", 10, "seed"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	l.EnablePQCMigration(true, time.Time{})
	if _, err := l.MigrateWithDualSignature("edge-a", "edge-a", 1, "same account", true, true); err == nil {
		t.Fatal("expected migration between identical accounts to fail")
	}
}

func TestMigrationRequiresBothLegacyAndPQCAccounts(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	l.EnablePQCMigration(true, time.Time{})
	if _, err := l.MigrateWithDualSignature("", "pqc", 1, "missing legacy", true, true); err == nil {
		t.Fatal("expected missing legacy account to fail")
	}
	if _, err := l.MigrateWithDualSignature("legacy", "", 1, "missing pqc", true, true); err == nil {
		t.Fatal("expected missing pqc account to fail")
	}
}

// TestMigrateWithDualSignatureCryptographic_EmptyBundleIsRejected is a
// regression test for a fixed security bug: verifyMigrationSignatureBundle()
// used to treat a bundle with both signatures blank as "not enabled" and
// return nil (no error) without verifying anything. Since
// MigrateWithDualSignatureCryptographic always invokes the ledger with
// cryptographic=true, calling it directly with a zero-value
// MigrationSignatureBundle used to authorize a migration with NO signature
// check at all -- including bypassing the post-epoch "cryptographic
// signatures required" enforcement in migrateWithDualSignatureUnits, since
// that check only guards the *boolean* (non-cryptographic) path.
//
// The exported entry point now rejects an empty/disabled bundle outright, so
// this can no longer happen regardless of caller discipline.
func TestMigrateWithDualSignatureCryptographic_EmptyBundleIsRejected(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "legacy-edge", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	l.ConfigurePQCMigration(true, time.Time{}, false)
	l.ConfigurePQCMigrationEpoch(time.Now().Add(-time.Minute), true) // post-epoch: crypto required

	_, err := l.MigrateWithDualSignatureCryptographic("legacy-edge", "pqc-edge", 1, "unverified", MigrationSignatureBundle{}, "", 0)
	if err == nil {
		t.Fatal("expected empty-bundle cryptographic migration to be rejected, got nil error")
	}
	if got := l.Balance("pqc-edge"); got != 0 {
		t.Fatalf("expected rejected migration to move no funds, got balance %v", got)
	}
	if got := l.Balance("legacy-edge"); got != 10 {
		t.Fatalf("expected rejected migration to leave legacy balance untouched, got %v", got)
	}
}
