package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

func TestUtilityCoinTaskSettlement(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "orch", 50, "fund"); err != nil {
		t.Fatalf("mint: %v", err)
	}
	if _, err := ledger.SettleTaskPayout("orch", "node-a", "task-1", 10, "proof-1", true, 1); err != nil {
		t.Fatalf("settle payout: %v", err)
	}
	if got := ledger.Balance("orch"); got != 40 {
		t.Fatalf("unexpected payer balance: %f", got)
	}
	if got := ledger.Balance("node-a"); got != 10 {
		t.Fatalf("unexpected worker balance: %f", got)
	}
}

func TestUtilityCoinTaskSettlementRequiresValidProof(t *testing.T) {
	ledger := token.NewLedger("MHC", "protocol")
	if _, err := ledger.Mint("protocol", "orch", 50, "fund"); err != nil {
		t.Fatalf("mint: %v", err)
	}
	if _, err := ledger.SettleTaskPayout("orch", "node-a", "task-2", 5, "proof-2", false, 2); err == nil {
		t.Fatal("expected settlement to fail without valid proof")
	}
}
