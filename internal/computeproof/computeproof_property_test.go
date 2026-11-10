package computeproof

import (
	"strings"
	"testing"
)

func TestProperty_BuildVerifyRoundTrip(t *testing.T) {
	trace := Trace{
		RoundID:               "r1",
		TaskHash:              "task",
		NodeID:                "node1",
		StepCount:             3,
		DatasetCommitment:     "ds",
		ModelCommitmentBefore: "mb",
		ModelCommitmentAfter:  "ma",
	}
	proof, err := BuildProof(trace, "challenge")
	if err != nil {
		t.Fatal(err)
	}
	v := NewVerifier()
	ok, err := v.Verify(trace, proof)
	if err != nil || !ok {
		t.Fatalf("verify failed: %v %v", err, ok)
	}
	// Tampered seal must fail.
	proof.Seal = strings.Repeat("0", len(proof.Seal))
	ok2, _ := v.Verify(trace, proof)
	if ok2 {
		t.Fatal("tampered proof accepted")
	}
}