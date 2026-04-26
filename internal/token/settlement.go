package token

import (
	"fmt"
	"strings"
)

// SettleTaskPayout transfers utility coin for a completed and verified compute task.
// Formalized policy linkage: Theorem7PQCMigrationContinuity + Theorem8DualSignatureNonHijack.
func (l *Ledger) SettleTaskPayout(payer string, worker string, taskID string, amount float64, proofID string, proofValid bool, nonce uint64) (Tx, error) {
	taskID = strings.TrimSpace(taskID)
	proofID = strings.TrimSpace(proofID)
	if taskID == "" || proofID == "" {
		return Tx{}, fmt.Errorf("task_id and proof_id are required")
	}
	if !proofValid {
		return Tx{}, fmt.Errorf("task payout requires a valid compute proof")
	}
	memo := fmt.Sprintf("task_settlement:%s:%s", taskID, proofID)
	idempotencyKey := fmt.Sprintf("task:%s:%s", taskID, proofID)
	return l.TransferWithControls(payer, worker, amount, memo, idempotencyKey, nonce)
}
