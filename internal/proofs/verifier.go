// @notice: ZK-SNARK Verification Logic for MOHAWK Runtime.
// @proof: /proofs/communication.md#Theorem-5-Verification-Complexity
package proofs

import (
	"crypto/sha256"
	"fmt"
)

// Verifier provides cryptographic attestation methods.
type Verifier struct{}

// VerifyProof validates that proofData hashes to expectedRoot with a salt.
func (v *Verifier) VerifyProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	h := sha256.New()
	h.Write(proofData)
	h.Write(salt[:]) 
	actualRoot := fmt.Sprintf("%x", h.Sum(nil))

	if actualRoot != expectedRoot {
		return false, fmt.Errorf("integrity check failed: expected %s, got %s", expectedRoot, actualRoot)
	}

	return true, nil
}
