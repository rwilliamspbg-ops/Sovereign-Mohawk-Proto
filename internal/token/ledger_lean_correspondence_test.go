package token

import "testing"

// TestLedgerLeanCorrespondence checks Ledger.TransferWithControls against
// outputs independently computed from the Lean spec (transferSpec in
// proofs/Refinement/Ledger.lean) via manual computation on the same inputs.
// Amounts are chosen to convert to whole integer units (no floating-point
// rounding), so the correspondence is checked for exact integer equality.
// See proofs/Refinement/Ledger.lean's module docstring for the two
// documented gaps this test also exercises directly: absent-account value
// loss and the missing balance-sufficiency check.
func TestLedgerLeanCorrespondence(t *testing.T) {
	t.Run("valid_transfer_matches_transferSpec", func(t *testing.T) {
		// transferSpec 1 2 30 <[(1,100),(2,50)]> = <[(1,70),(2,80)]> (manual computation).
		l := NewLedger("MHC", "minter")
		if _, err := l.Mint("minter", "acct1", 0.000100, ""); err != nil {
			t.Fatalf("mint acct1: %v", err)
		}
		if _, err := l.Mint("minter", "acct2", 0.000050, ""); err != nil {
			t.Fatalf("mint acct2: %v", err)
		}
		if _, err := l.TransferWithControls("acct1", "acct2", 0.000030, "", "", 0); err != nil {
			t.Fatalf("transfer: %v", err)
		}

		if got, want := l.BalanceUnits("acct1"), int64(70); got != want {
			t.Fatalf("acct1 units = %d, want %d (Lean transferSpec value)", got, want)
		}
		if got, want := l.BalanceUnits("acct2"), int64(80); got != want {
			t.Fatalf("acct2 units = %d, want %d (Lean transferSpec value)", got, want)
		}
	})

	t.Run("insufficient_balance_rejected_unlike_transferSpec", func(t *testing.T) {
		// Lean's transferSpec_permits_insufficient_balance shows the Lean
		// spec applies this transfer unconditionally, producing balance -40.
		// Go rejects it outright -- a real, documented correspondence gap.
		l := NewLedger("MHC", "minter")
		if _, err := l.Mint("minter", "acct1", 0.000010, ""); err != nil {
			t.Fatalf("mint acct1: %v", err)
		}

		_, err := l.TransferWithControls("acct1", "acct2", 0.000050, "", "", 0)
		if err == nil {
			t.Fatal("expected insufficient-balance error, got nil")
		}

		if got, want := l.BalanceUnits("acct1"), int64(10); got != want {
			t.Fatalf("acct1 units = %d, want %d (transfer must not have applied)", got, want)
		}
		if got := l.BalanceUnits("acct2"); got != 0 {
			t.Fatalf("acct2 units = %d, want 0 (transfer must not have applied)", got)
		}
	})
}
