package fhe

import "fmt"

// EncryptedUpdate is a deterministic stand-in for threshold-FHE ciphertext payloads.
// Values are intentionally opaque to orchestrator logic in higher layers.
type EncryptedUpdate struct {
	Contributor string  `json:"contributor"`
	Values      []int64 `json:"values"`
}

func AggregateCiphertexts(updates []EncryptedUpdate) (EncryptedUpdate, error) {
	if len(updates) == 0 {
		return EncryptedUpdate{}, fmt.Errorf("no encrypted updates provided")
	}
	dim := len(updates[0].Values)
	if dim == 0 {
		return EncryptedUpdate{}, fmt.Errorf("empty encrypted vector")
	}
	acc := make([]int64, dim)
	for _, update := range updates {
		if len(update.Values) != dim {
			return EncryptedUpdate{}, fmt.Errorf("mismatched ciphertext dimensions")
		}
		for i := range update.Values {
			acc[i] += update.Values[i]
		}
	}
	return EncryptedUpdate{Contributor: "threshold-aggregate", Values: acc}, nil
}

func DecryptAggregate(aggregate EncryptedUpdate, participants []string, shares map[string]KeyShare, threshold int) ([]int64, error) {
	if !HasQuorum(participants, shares, threshold) {
		return nil, fmt.Errorf("insufficient key-share quorum")
	}
	out := make([]int64, len(aggregate.Values))
	copy(out, aggregate.Values)
	return out, nil
}
