// @notice: Tests for ZK-SNARK Verification Logic for MOHAWK Runtime.
package proofs

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"strings"
	"testing"
)

// sha256Hex mirrors the hashing rule implemented by VerifyZKProof: the hex
// SHA-256 digest of proofData, with salt appended only when salt is not the
// all-zero value. It is written independently of the production code so
// that the test asserts the *specification*, not just "whatever the code
// currently does".
func sha256Hex(proofData []byte, salt [32]byte) string {
	var emptySalt [32]byte
	buf := append([]byte{}, proofData...)
	if salt != emptySalt {
		buf = append(buf, salt[:]...)
	}
	sum := sha256.Sum256(buf)
	return fmt.Sprintf("%x", sum)
}

func TestVerifyZKProof_EmptyDataZeroSalt(t *testing.T) {
	// Well-known SHA-256 of the empty byte string.
	root := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	valid, err := VerifyZKProof(root, []byte(""), [32]byte{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !valid {
		t.Fatal("expected proof to be valid")
	}
}

func TestVerifyZKProof_ArbitraryDataZeroSalt(t *testing.T) {
	data := []byte("federated-round-42-gradient-commitment")
	salt := [32]byte{}
	root := sha256Hex(data, salt)

	valid, err := VerifyZKProof(root, data, salt)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !valid {
		t.Fatal("expected proof to be valid for correctly derived root")
	}
}

func TestVerifyZKProof_ArbitraryDataWithNonZeroSalt(t *testing.T) {
	data := []byte("aggregator-batch-commitment")
	var salt [32]byte
	for i := range salt {
		salt[i] = byte(i + 1)
	}
	root := sha256Hex(data, salt)

	valid, err := VerifyZKProof(root, data, salt)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !valid {
		t.Fatal("expected proof to be valid when salt is folded into the hash")
	}

	// Sanity: the salted root must differ from the unsalted root, otherwise
	// the salt would not actually be contributing to the commitment.
	unsaltedRoot := sha256Hex(data, [32]byte{})
	if root == unsaltedRoot {
		t.Fatal("salted root unexpectedly equals unsalted root")
	}
}

// A non-zero salt that does not match the one used to derive expectedRoot
// must cause verification to fail — the salt is part of the commitment, not
// a decorative parameter.
func TestVerifyZKProof_WrongSaltRejected(t *testing.T) {
	data := []byte("commitment-data")
	var correctSalt, wrongSalt [32]byte
	correctSalt[0] = 0xAA
	wrongSalt[0] = 0xBB

	root := sha256Hex(data, correctSalt)

	valid, err := VerifyZKProof(root, data, wrongSalt)
	if err == nil {
		t.Fatal("expected error when salt does not match the one used to derive the root")
	}
	if valid {
		t.Fatal("expected proof to be invalid for mismatched salt")
	}
}

// The all-zero salt is treated as "no salt": VerifyZKProof must not fold it
// into the hash. This pins down that documented (if surprising) behavior so
// a refactor can't silently change it without a failing test.
func TestVerifyZKProof_ZeroSaltIsNotFoldedIn(t *testing.T) {
	data := []byte("no-salt-case")
	sum := sha256.Sum256(data)
	plainRoot := fmt.Sprintf("%x", sum)

	valid, err := VerifyZKProof(plainRoot, data, [32]byte{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !valid {
		t.Fatal("expected zero salt to be equivalent to omitting the salt entirely")
	}
}

func TestVerifyZKProof_TamperedProofDataRejected(t *testing.T) {
	original := []byte("original-gradient-payload")
	tampered := []byte("original-gradient-payload!") // one byte appended
	salt := [32]byte{}

	root := sha256Hex(original, salt)

	valid, err := VerifyZKProof(root, tampered, salt)
	if err == nil {
		t.Fatal("expected error for tampered proof data")
	}
	if valid {
		t.Fatal("expected tampered proof data to be rejected")
	}
}

func TestVerifyZKProof_SingleBitFlipRejected(t *testing.T) {
	original := []byte("bit-flip-sensitivity-check")
	salt := [32]byte{}
	root := sha256Hex(original, salt)

	flipped := append([]byte{}, original...)
	flipped[0] ^= 0x01 // flip the low bit of the first byte

	valid, err := VerifyZKProof(root, flipped, salt)
	if err == nil {
		t.Fatal("expected error for single-bit-flipped proof data")
	}
	if valid {
		t.Fatal("expected single-bit-flipped proof data to be rejected (avalanche property)")
	}
}

func TestVerifyZKProof_WrongExpectedRootRejected(t *testing.T) {
	valid, err := VerifyZKProof("invalid_root", []byte("some data"), [32]byte{})
	if err == nil {
		t.Fatal("expected error for mismatched root")
	}
	if valid {
		t.Fatal("expected proof to be invalid for mismatched root")
	}
}

// The comparison against expectedRoot is a plain string compare against a
// lowercase hex digest (fmt.Sprintf("%x", ...)); an uppercase-but-otherwise-
// correct root must NOT verify. This documents that callers are expected to
// supply lowercase hex, it is not a bug for this test to fail if that
// contract ever changes intentionally.
func TestVerifyZKProof_UppercaseRootRejected(t *testing.T) {
	data := []byte("case-sensitivity-check")
	salt := [32]byte{}
	root := sha256Hex(data, salt)
	upperRoot := strings.ToUpper(root)
	if upperRoot == root {
		t.Fatal("test fixture error: expected upper/lower case forms to differ")
	}

	valid, err := VerifyZKProof(upperRoot, data, salt)
	if err == nil {
		t.Fatal("expected error for uppercase root not matching lowercase digest")
	}
	if valid {
		t.Fatal("expected uppercase root to be rejected")
	}
}

func TestVerifyZKProof_EmptyExpectedRootRejected(t *testing.T) {
	valid, err := VerifyZKProof("", []byte("some data"), [32]byte{})
	if err == nil {
		t.Fatal("expected error for empty expected root")
	}
	if valid {
		t.Fatal("expected proof to be invalid for empty expected root")
	}
}

// nil and empty ([]byte{}) proof data must hash identically: sha256.Write
// treats them the same way, and VerifyZKProof must too.
func TestVerifyZKProof_NilProofDataEquivalentToEmpty(t *testing.T) {
	salt := [32]byte{}
	root := sha256Hex([]byte(""), salt)

	valid, err := VerifyZKProof(root, nil, salt)
	if err != nil {
		t.Fatalf("expected no error for nil proof data, got %v", err)
	}
	if !valid {
		t.Fatal("expected nil proof data to verify the same as empty proof data")
	}
}

func TestVerifyZKProof_LargeProofData(t *testing.T) {
	// 1 MiB payload to exercise a "max-size-ish" input rather than only tiny
	// fixtures.
	data := bytes.Repeat([]byte{0x5A}, 1<<20)
	salt := [32]byte{}
	root := sha256Hex(data, salt)

	valid, err := VerifyZKProof(root, data, salt)
	if err != nil {
		t.Fatalf("expected no error for large payload, got %v", err)
	}
	if !valid {
		t.Fatal("expected large proof data to verify against its correct root")
	}
}

// The error returned on mismatch is used for operator-facing diagnostics; it
// should surface both the expected and actual computed roots.
func TestVerifyZKProof_ErrorMessageContainsBothRoots(t *testing.T) {
	data := []byte("diagnostic-message-check")
	salt := [32]byte{}
	actualRoot := sha256Hex(data, salt)
	expectedRoot := "deadbeef"

	_, err := VerifyZKProof(expectedRoot, data, salt)
	if err == nil {
		t.Fatal("expected an error")
	}
	msg := err.Error()
	if !strings.Contains(msg, expectedRoot) {
		t.Errorf("expected error to contain expected root %q, got: %q", expectedRoot, msg)
	}
	if !strings.Contains(msg, actualRoot) {
		t.Errorf("expected error to contain actual computed root %q, got: %q", actualRoot, msg)
	}
}

func TestVerifyZKProof_Deterministic(t *testing.T) {
	data := []byte("determinism-check")
	salt := [32]byte{0x01}
	root := sha256Hex(data, salt)

	for i := 0; i < 5; i++ {
		valid, err := VerifyZKProof(root, data, salt)
		if err != nil {
			t.Fatalf("iteration %d: unexpected error: %v", i, err)
		}
		if !valid {
			t.Fatalf("iteration %d: expected valid", i)
		}
	}
}

func TestVerifyZKProof_TableDriven(t *testing.T) {
	dataA := []byte("payload-a")
	dataB := []byte("payload-b")
	var saltA, saltB [32]byte
	saltA[5] = 0x42
	saltB[5] = 0x43

	tests := []struct {
		name         string
		expectedRoot string
		proofData    []byte
		salt         [32]byte
		wantValid    bool
	}{
		{
			name:         "matching data, zero salt",
			expectedRoot: sha256Hex(dataA, [32]byte{}),
			proofData:    dataA,
			salt:         [32]byte{},
			wantValid:    true,
		},
		{
			name:         "matching data, non-zero salt",
			expectedRoot: sha256Hex(dataA, saltA),
			proofData:    dataA,
			salt:         saltA,
			wantValid:    true,
		},
		{
			name:         "root computed for different data",
			expectedRoot: sha256Hex(dataA, [32]byte{}),
			proofData:    dataB,
			salt:         [32]byte{},
			wantValid:    false,
		},
		{
			name:         "root computed with different salt",
			expectedRoot: sha256Hex(dataA, saltA),
			proofData:    dataA,
			salt:         saltB,
			wantValid:    false,
		},
		{
			name:         "empty data, empty root",
			expectedRoot: "",
			proofData:    []byte{},
			salt:         [32]byte{},
			wantValid:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			valid, err := VerifyZKProof(tt.expectedRoot, tt.proofData, tt.salt)
			if valid != tt.wantValid {
				t.Fatalf("VerifyZKProof() valid = %v, want %v (err=%v)", valid, tt.wantValid, err)
			}
			if tt.wantValid && err != nil {
				t.Fatalf("expected no error for valid case, got %v", err)
			}
			if !tt.wantValid && err == nil {
				t.Fatalf("expected an error for invalid case, got nil")
			}
		})
	}
}

// --- Verifier (receiver) tests -------------------------------------------

func TestVerifier_VerifyProof_MatchesStandaloneFunction_Valid(t *testing.T) {
	data := []byte("aggregator-round-commitment")
	salt := [32]byte{0x09}
	root := sha256Hex(data, salt)

	v := &Verifier{}
	valid, err := v.VerifyProof(root, data, salt)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !valid {
		t.Fatal("expected Verifier.VerifyProof to accept a correctly derived root")
	}

	// Cross-check against the standalone function directly to make sure the
	// method is a pure pass-through and not silently diverging.
	wantValid, wantErr := VerifyZKProof(root, data, salt)
	if valid != wantValid {
		t.Fatalf("Verifier.VerifyProof valid=%v differs from VerifyZKProof valid=%v", valid, wantValid)
	}
	if (err == nil) != (wantErr == nil) {
		t.Fatalf("Verifier.VerifyProof err=%v differs (nil-ness) from VerifyZKProof err=%v", err, wantErr)
	}
}

func TestVerifier_VerifyProof_MatchesStandaloneFunction_Invalid(t *testing.T) {
	v := &Verifier{}
	valid, err := v.VerifyProof("not-a-real-root", []byte("payload"), [32]byte{})
	if err == nil {
		t.Fatal("expected error for invalid proof via Verifier.VerifyProof")
	}
	if valid {
		t.Fatal("expected Verifier.VerifyProof to reject an incorrect root")
	}
}

// The zero-value Verifier must be directly usable (as internal/batch does
// with &proofs.Verifier{}) without any additional construction step.
func TestVerifier_ZeroValueUsable(t *testing.T) {
	var v Verifier
	root := sha256Hex([]byte(""), [32]byte{})
	valid, err := v.VerifyProof(root, []byte(""), [32]byte{})
	if err != nil {
		t.Fatalf("expected no error from zero-value Verifier, got %v", err)
	}
	if !valid {
		t.Fatal("expected zero-value Verifier to verify a correct proof")
	}
}
