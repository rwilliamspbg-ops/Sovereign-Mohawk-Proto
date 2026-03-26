package test

import (
	"testing"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

func TestUtilityCoinMintAndTransfer(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")

	if _, err := ledger.Mint("protocol", "edge-a", 100, "bootstrap"); err != nil {
		t.Fatalf("mint failed: %v", err)
	}
	if got := ledger.Balance("edge-a"); got != 100 {
		t.Fatalf("unexpected edge-a balance: %.4f", got)
	}

	if _, err := ledger.Transfer("edge-a", "edge-b", 24.5, "service payment"); err != nil {
		t.Fatalf("transfer failed: %v", err)
	}
	if got := ledger.Balance("edge-a"); got != 75.5 {
		t.Fatalf("unexpected edge-a balance after transfer: %.4f", got)
	}
	if got := ledger.Balance("edge-b"); got != 24.5 {
		t.Fatalf("unexpected edge-b balance after transfer: %.4f", got)
	}
}

func TestUtilityCoinMintAuthAndInsufficientFunds(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")

	if _, err := ledger.Mint("attacker", "edge-a", 10, "unauthorized"); err == nil {
		t.Fatal("expected unauthorized mint to fail")
	}

	if _, err := ledger.Mint("protocol", "edge-a", 5, "seed"); err != nil {
		t.Fatalf("authorized mint failed: %v", err)
	}
	if _, err := ledger.Transfer("edge-a", "edge-b", 6, "too much"); err == nil {
		t.Fatal("expected insufficient-funds transfer to fail")
	}
}

func TestUtilityCoinDualSignatureMigration(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "legacy-edge", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}

	if _, err := ledger.MigrateWithDualSignature("legacy-edge", "mldsa-edge", 2, "migration", true, true); err == nil {
		t.Fatal("expected migration to fail while migration period is disabled")
	}

	ledger.EnablePQCMigration(true, time.Now().Add(24*time.Hour))
	if _, err := ledger.MigrateWithDualSignature("legacy-edge", "mldsa-edge", 2.5, "migration", false, true); err == nil {
		t.Fatal("expected migration to fail without both signatures")
	}

	tx, err := ledger.MigrateWithDualSignature("legacy-edge", "mldsa-edge", 2.5, "migration", true, true)
	if err != nil {
		t.Fatalf("migration failed: %v", err)
	}
	if tx.Type != token.TxMigrate {
		t.Fatalf("expected migration tx type %q, got %q", token.TxMigrate, tx.Type)
	}
	if got := ledger.Balance("legacy-edge"); got != 7.5 {
		t.Fatalf("unexpected legacy balance after migration: %.4f", got)
	}
	if got := ledger.Balance("mldsa-edge"); got != 2.5 {
		t.Fatalf("unexpected pqc balance after migration: %.4f", got)
	}
	if _, err := ledger.MigrateWithDualSignature("legacy-edge", "another-pqc", 1, "remap", true, true); err == nil {
		t.Fatal("expected remapping legacy account to a different pqc account to fail")
	}
}

func TestUtilityCoinMigrationLocksLegacyTransfersWhenEnabled(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "legacy-edge", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	ledger.ConfigurePQCMigration(true, time.Now().Add(24*time.Hour), true)
	if _, err := ledger.MigrateWithDualSignature("legacy-edge", "mldsa-edge", 4, "migration", true, true); err != nil {
		t.Fatalf("migration failed: %v", err)
	}

	if _, err := ledger.Transfer("legacy-edge", "edge-b", 1, "post-migration transfer"); err == nil {
		t.Fatal("expected legacy transfer to fail when legacy lock is enabled")
	}
	if _, err := ledger.Burn("legacy-edge", 1, "post-migration burn"); err == nil {
		t.Fatal("expected legacy burn to fail when legacy lock is enabled")
	}
	if _, err := ledger.Transfer("mldsa-edge", "edge-b", 1, "pqc transfer"); err != nil {
		t.Fatalf("expected pqc transfer to succeed, got %v", err)
	}
}

func TestUtilityCoinMigrationNonceAndIdempotency(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "legacy-edge", 10, "seed"); err != nil {
		t.Fatalf("seed mint failed: %v", err)
	}
	ledger.ConfigurePQCMigration(true, time.Now().Add(24*time.Hour), false)

	first, err := ledger.MigrateWithDualSignatureControls("legacy-edge", "mldsa-edge", 3, "migration", true, true, "mig-1", 10)
	if err != nil {
		t.Fatalf("first migration failed: %v", err)
	}
	dup, err := ledger.MigrateWithDualSignatureControls("legacy-edge", "mldsa-edge", 99, "dup", true, true, "mig-1", 10)
	if err != nil {
		t.Fatalf("idempotent migration should succeed: %v", err)
	}
	if first.Timestamp != dup.Timestamp || first.Amount != dup.Amount {
		t.Fatal("idempotent migration did not return original transaction")
	}
	if _, err := ledger.MigrateWithDualSignatureControls("legacy-edge", "mldsa-edge", 1, "replay", true, true, "mig-2", 10); err == nil {
		t.Fatal("expected migration nonce replay to fail")
	}
}
