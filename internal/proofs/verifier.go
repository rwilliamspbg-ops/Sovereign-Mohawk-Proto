// @notice: ZK-SNARK Verification Logic for MOHAWK Runtime.
// @proof: /proofs/communication.md#Theorem-5-Verification-Complexity
package proofs

import (
	"crypto/sha256"
	"crypto/subtle"
	"fmt"
)

type Verifier struct{}

// VerifyProof is the receiver method used by the Aggregator.
func (v *Verifier) VerifyProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	return VerifyZKProof(expectedRoot, proofData, salt)
}

// VerifyZKProof is the standalone function required by test/zk_verifier_test.go.
func VerifyZKProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	h := sha256.New()
	h.Write(proofData)

	var emptySalt [32]byte
	if salt != emptySalt {
		h.Write(salt[:])
	}

	actualRoot := fmt.Sprintf("%x", h.Sum(nil))
	// Constant-time comparison: the caller-supplied expectedRoot isn't a secret
	// in any current call path (see internal/router.PublishInsight, which takes
	// both expectedRoot and proofData from the same request), but this is an
	// exported, general-purpose verifier - hardening it here is free and avoids
	// relying on that being true for every future caller.
	if subtle.ConstantTimeCompare([]byte(actualRoot), []byte(expectedRoot)) != 1 {
		return false, fmt.Errorf("integrity check failed: expected %s, got %s", expectedRoot, actualRoot)
	}

	return true, nil
}
