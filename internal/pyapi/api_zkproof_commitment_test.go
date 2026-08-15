//go:build cgo

// Tests here exercise the plain-Go decision logic behind VerifyZKProof and
// BatchVerifyProofs (parseCommitmentHex, extractCommitment,
// verifyProofPayload) rather than the //export functions themselves — the
// same convention already used for AggregateUpdates/aggregateUpdatesCore in
// this package, since a `package main` intended for `-buildmode=c-shared`
// cannot build cgo (*C.char-crossing) code in a test binary.
package main

import (
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestExtractCommitment(t *testing.T) {
	if got, err := extractCommitment(map[string]any{}); err != nil || got != nil {
		t.Fatalf("expected (nil, nil) when commitment key is absent, got (%v, %v)", got, err)
	}
	if got, err := extractCommitment(map[string]any{"commitment": 12345}); err != nil || got != nil {
		t.Fatalf("expected a non-string commitment value to be treated as absent, got (%v, %v)", got, err)
	}
	if got, err := extractCommitment(map[string]any{"commitment": "0xabc"}); err != nil || got == nil || got.Text(16) != "abc" {
		t.Fatalf("expected 0xabc to parse, got (%v, %v)", got, err)
	}
	if _, err := extractCommitment(map[string]any{"commitment": "!!!"}); err == nil {
		t.Fatalf("expected an error for a malformed commitment field")
	}
}

func TestVerifyProofPayload_CommitmentBound_ValidProof(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("gradient-round-42"))
	proofBytes, commitment, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	valid, err := verifyProofPayload(proofBytes, commitment)
	if err != nil {
		t.Fatalf("verifyProofPayload: %v", err)
	}
	if !valid {
		t.Fatalf("expected a genuine commitment-bound proof to verify true")
	}
}

func TestVerifyProofPayload_CommitmentBound_MismatchedCommitment(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("gradient-round-42"))
	proofBytes, _, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	wrongPreimage := internalpkg.DataCommitmentDigest([]byte("a-completely-different-payload"))
	_, wrongCommitment, err := internalpkg.ProveDataCommitment(wrongPreimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment (wrong): %v", err)
	}

	valid, err := verifyProofPayload(proofBytes, wrongCommitment)
	if valid {
		t.Fatalf("expected a proof/commitment mismatch to fail verification, got valid=true (err=%v)", err)
	}
}

func TestVerifyProofPayload_CommitmentAbsent_UsesLegacyGenesisPath(t *testing.T) {
	// nil commitment: must fall back to the pre-existing genesis-VK path
	// unchanged, so old callers that never send a commitment keep working
	// exactly as before this change.
	valid, err := verifyProofPayload(internalpkg.GenesisProofBytes(), nil)
	if err != nil {
		t.Fatalf("verifyProofPayload (legacy path): %v", err)
	}
	if !valid {
		t.Fatalf("expected legacy genesis-path verification to still succeed")
	}
}

func TestVerifyProofPayload_CommitmentCircuitProofRejectedByLegacyPath(t *testing.T) {
	// A commitment-circuit proof is not a valid genesis-VK proof — passing
	// nil commitment (the legacy path) for one must not accidentally
	// succeed, or the two verification paths would be silently conflatable.
	preimage := internalpkg.DataCommitmentDigest([]byte("routing-test"))
	proofBytes, _, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	valid, err := verifyProofPayload(proofBytes, nil)
	if err == nil && valid {
		t.Fatalf("expected a commitment-circuit proof to fail against the unrelated legacy genesis path, got valid=true")
	}
}
