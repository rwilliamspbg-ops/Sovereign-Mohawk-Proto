// @notice: SHA-256 commitment/integrity verification for MOHAWK Runtime.
//
// This package checks that supplied proofData hashes (optionally salted) to
// an expected commitment root. It is a keyed hash-commitment equality check:
// it has none of the properties that make something a zk-SNARK (no
// succinctness relative to a witness, no zero-knowledge property, no
// soundness under a computational hardness assumption beyond SHA-256
// collision/preimage resistance). Earlier revisions of this file and its
// exported names called this "ZK-SNARK Verification Logic" — that was
// inaccurate. For genuine zk-SNARK (Groth16/BN254 pairing) verification, see
// internal/zksnark_verifier.go.
//
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
	return VerifyHashCommitment(expectedRoot, proofData, salt)
}

// VerifyHashCommitment checks that SHA-256(proofData [|| salt]) equals
// expectedRoot. This is a hash-commitment integrity check, not a
// zero-knowledge proof of any kind: it establishes that the caller possesses
// data matching a previously published digest, nothing more (no succinctness
// relative to a larger witness, no hiding property beyond what SHA-256's
// preimage resistance provides).
func VerifyHashCommitment(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
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

// VerifyZKProof is a compatibility alias for VerifyHashCommitment, kept
// because test/zk_verifier_test.go and other callers reference it by this
// name. Despite the name, it performs a SHA-256 hash-commitment check, not
// zk-SNARK verification — see the package doc comment above.
//
// Deprecated: call VerifyHashCommitment directly; this name is misleading
// and exists only for backward compatibility with existing call sites.
func VerifyZKProof(expectedRoot string, proofData []byte, salt [32]byte) (bool, error) {
	return VerifyHashCommitment(expectedRoot, proofData, salt)
}
