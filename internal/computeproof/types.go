package computeproof

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
)

// Trace captures deterministic execution metadata used for proof-of-compute.
type Trace struct {
	RoundID               string `json:"round_id"`
	TaskHash              string `json:"task_hash"`
	NodeID                string `json:"node_id"`
	StepCount             int    `json:"step_count"`
	DatasetCommitment     string `json:"dataset_commitment"`
	ModelCommitmentBefore string `json:"model_commitment_before"`
	ModelCommitmentAfter  string `json:"model_commitment_after"`
}

// Proof is a compact transcript commitment plus challenge binding.
type Proof struct {
	TraceHash string `json:"trace_hash"`
	Challenge string `json:"challenge"`
	Seal      string `json:"seal"`
}

func (t Trace) Validate() error {
	if strings.TrimSpace(t.RoundID) == "" || strings.TrimSpace(t.TaskHash) == "" || strings.TrimSpace(t.NodeID) == "" {
		return fmt.Errorf("round_id, task_hash, and node_id are required")
	}
	if t.StepCount <= 0 {
		return fmt.Errorf("step_count must be positive")
	}
	if strings.TrimSpace(t.DatasetCommitment) == "" || strings.TrimSpace(t.ModelCommitmentBefore) == "" || strings.TrimSpace(t.ModelCommitmentAfter) == "" {
		return fmt.Errorf("dataset/model commitments are required")
	}
	return nil
}

func (t Trace) CanonicalBytes() ([]byte, error) {
	if err := t.Validate(); err != nil {
		return nil, err
	}
	return json.Marshal(t)
}

func (t Trace) Hash() (string, error) {
	encoded, err := t.CanonicalBytes()
	if err != nil {
		return "", err
	}
	d := sha256.Sum256(encoded)
	return hex.EncodeToString(d[:]), nil
}

// BuildProof creates a deterministic proof binding trace hash and challenge.
func BuildProof(trace Trace, challenge string) (Proof, error) {
	challenge = strings.TrimSpace(challenge)
	if challenge == "" {
		return Proof{}, fmt.Errorf("challenge is required")
	}
	traceHash, err := trace.Hash()
	if err != nil {
		return Proof{}, err
	}
	sealBytes := sha256.Sum256([]byte(traceHash + ":" + challenge))
	return Proof{
		TraceHash: traceHash,
		Challenge: challenge,
		Seal:      hex.EncodeToString(sealBytes[:]),
	}, nil
}
