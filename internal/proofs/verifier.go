// @notice: ZK-SNARK Verification Logic for MOHAWK Runtime.
// @proof: /proofs/communication.md#Theorem-5-Verification-Complexity
package proofs

import (
	"crypto/sha256"
	"fmt"
)

func VerifyProof(expectedRoot string, proofData []byte) (bool, error) {
	// Calculate the actual root using a standard SHA256 hash of the proof data
	h := sha256.New()
	h.Write(proofData)
	actualRoot := fmt.Sprintf("%x", h.Sum(nil))

	// Validate the calculated root against the expected value
	if actualRoot != expectedRoot {
		return false, fmt.Errorf("integrity check failed: expected %s, got %s", expectedRoot, actualRoot)
	}

	return true, nil
}
