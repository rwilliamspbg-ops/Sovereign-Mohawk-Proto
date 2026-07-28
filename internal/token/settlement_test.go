package token

import "testing"

func TestSettleTaskPayoutRequiresTaskAndProofID(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 10, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	if _, err := l.SettleTaskPayout("orch", "node-a", "", 5, "proof-1", true, 1); err == nil {
		t.Fatal("expected missing task_id to fail")
	}
	if _, err := l.SettleTaskPayout("orch", "node-a", "task-1", 5, "", true, 1); err == nil {
		t.Fatal("expected missing proof_id to fail")
	}
}

func TestSettleTaskPayoutRequiresValidProof(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 10, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	if _, err := l.SettleTaskPayout("orch", "node-a", "task-1", 5, "proof-1", false, 1); err == nil {
		t.Fatal("expected settlement without a valid proof to fail")
	}
	if got := l.Balance("orch"); got != 10 {
		t.Fatalf("expected no funds moved on invalid proof, got %v", got)
	}
}

func TestSettleTaskPayoutMovesFunds(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 50, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	if _, err := l.SettleTaskPayout("orch", "node-a", "task-1", 10, "proof-1", true, 1); err != nil {
		t.Fatalf("settle failed: %v", err)
	}
	if got := l.Balance("orch"); got != 40 {
		t.Fatalf("unexpected payer balance: %v", got)
	}
	if got := l.Balance("node-a"); got != 10 {
		t.Fatalf("unexpected worker balance: %v", got)
	}
}

func TestSettleTaskPayoutIsIdempotentPerTaskAndProof(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 50, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	first, err := l.SettleTaskPayout("orch", "node-a", "task-1", 10, "proof-1", true, 1)
	if err != nil {
		t.Fatalf("first settle failed: %v", err)
	}
	// Same task_id/proof_id pair (regardless of nonce/amount) must be treated
	// as a retry of the same settlement and short-circuit via idempotency.
	second, err := l.SettleTaskPayout("orch", "node-a", "task-1", 999, "proof-1", true, 2)
	if err != nil {
		t.Fatalf("second settle failed: %v", err)
	}
	if first.Timestamp != second.Timestamp || first.Amount != second.Amount {
		t.Fatal("expected retried settlement to return the original transaction")
	}
	if got := l.Balance("node-a"); got != 10 {
		t.Fatalf("expected funds moved only once, got balance %v", got)
	}
}

func TestSettleTaskPayoutMemoEncodesTaskAndProof(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 50, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	tx, err := l.SettleTaskPayout("orch", "node-a", "task-xyz", 1, "proof-xyz", true, 1)
	if err != nil {
		t.Fatalf("settle failed: %v", err)
	}
	want := "task_settlement:task-xyz:proof-xyz"
	if tx.Memo != want {
		t.Fatalf("expected memo %q, got %q", want, tx.Memo)
	}
}

func TestSettleTaskPayoutInsufficientFunds(t *testing.T) {
	l := NewLedger("MHC", "protocol")
	if _, err := l.Mint("protocol", "orch", 1, "fund"); err != nil {
		t.Fatalf("fund mint failed: %v", err)
	}
	if _, err := l.SettleTaskPayout("orch", "node-a", "task-1", 100, "proof-1", true, 1); err == nil {
		t.Fatal("expected settlement exceeding payer balance to fail")
	}
}
