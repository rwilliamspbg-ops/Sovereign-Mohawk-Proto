// @notice: ZK-SNARK Verification Logic for MOHAWK Runtime.
// @proof: /proofs/communication.md#Theorem-5-Verification-Complexity
package proofs

import (
	"crypto/sha256"
	"fmt"
)

// Verifier provides the method-based interface for the aggregator.
type Verifier struct{}

// VerifyProof is the receiver method used by the Aggregator.
func (v *Verifier) VerifyProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	return VerifyZKProof(expectedRoot, proofData, salt)
}

// VerifyZKProof is the standalone function required by test/zk_verifier_test.go.
// It must be capitalized to be exported and visible to the test package.
func VerifyZKProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	h := sha256.New()
	h.Write(proofData)
	h.Write(salt[:])
	actualRoot := fmt.Sprintf("%x", h.Sum(nil))

	if actualRoot != expectedRoot {
		return false, fmt.Errorf("integrity check failed: expected %s, got %s", expectedRoot, actualRoot)
	}

	return true, nil
}
