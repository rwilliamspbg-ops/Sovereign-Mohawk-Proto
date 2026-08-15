package hybrid

import (
	"testing"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

func TestSNARKVerifier_CommitmentBound_ValidProof(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("hybrid-round-1"))
	proofBytes, commitment, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	valid, err := (snarkVerifier{}).Verify(proofBytes, commitment)
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if !valid {
		t.Fatalf("expected a genuine commitment-bound proof to verify true")
	}
}

func TestSNARKVerifier_CommitmentBound_MismatchedCommitment(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("hybrid-round-1"))
	proofBytes, _, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}
	wrongPreimage := internalpkg.DataCommitmentDigest([]byte("hybrid-round-wrong"))
	_, wrongCommitment, err := internalpkg.ProveDataCommitment(wrongPreimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment (wrong): %v", err)
	}

	valid, err := (snarkVerifier{}).Verify(proofBytes, wrongCommitment)
	if valid {
		t.Fatalf("expected a proof/commitment mismatch to fail verification, got valid=true (err=%v)", err)
	}
}

func TestSNARKVerifier_CommitmentAbsent_UsesLegacyGenesisPath(t *testing.T) {
	valid, err := (snarkVerifier{}).Verify(internalpkg.GenesisProofBytes(), nil)
	if err != nil {
		t.Fatalf("Verify (legacy path): %v", err)
	}
	if !valid {
		t.Fatalf("expected legacy genesis-path verification to still succeed")
	}
}

func TestVerifyHybrid_CommitmentBound_EndToEnd(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("hybrid-e2e-round"))
	proofBytes, commitment, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}

	result, err := VerifyHybrid(VerifyRequest{
		Mode:       ModePreferSNARK,
		SNARKProof: proofBytes,
		Commitment: "0x" + commitment.Text(16),
		STARKProof: GenFRIProof([]byte("irrelevant-stark-content-for-this-test-1234567890")),
	})
	if err != nil {
		t.Fatalf("VerifyHybrid: %v", err)
	}
	if !result.SNARKValid {
		t.Fatalf("expected SNARKValid=true for a genuine commitment-bound proof, got %+v", result)
	}
	if !result.Accepted {
		t.Fatalf("expected Accepted=true, got %+v", result)
	}
}

func TestVerifyHybrid_CommitmentBound_RejectsMismatch(t *testing.T) {
	preimage := internalpkg.DataCommitmentDigest([]byte("hybrid-e2e-round"))
	proofBytes, _, err := internalpkg.ProveDataCommitment(preimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment: %v", err)
	}
	wrongPreimage := internalpkg.DataCommitmentDigest([]byte("hybrid-e2e-round-wrong"))
	_, wrongCommitment, err := internalpkg.ProveDataCommitment(wrongPreimage)
	if err != nil {
		t.Fatalf("ProveDataCommitment (wrong): %v", err)
	}

	result, err := VerifyHybrid(VerifyRequest{
		Mode:       ModeBoth,
		SNARKProof: proofBytes,
		Commitment: "0x" + wrongCommitment.Text(16),
		STARKProof: GenFRIProof([]byte("irrelevant-stark-content-for-this-test-1234567890")),
	})
	if err == nil {
		t.Fatalf("expected ModeBoth to reject a SNARK/commitment mismatch, got success result=%+v", result)
	}
	if result.SNARKValid {
		t.Fatalf("expected SNARKValid=false for a mismatched commitment, got %+v", result)
	}
}

func TestVerifyHybrid_MalformedCommitment_ReturnsError(t *testing.T) {
	_, err := VerifyHybrid(VerifyRequest{
		Mode:       ModePreferSNARK,
		SNARKProof: internalpkg.GenesisProofBytes(),
		Commitment: "not-valid-hex!!",
		STARKProof: GenFRIProof([]byte("irrelevant-stark-content-for-this-test-1234567890")),
	})
	if err == nil {
		t.Fatalf("expected a malformed commitment to error before verification runs")
	}
}
