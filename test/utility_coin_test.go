package test

import (
	"testing"

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
