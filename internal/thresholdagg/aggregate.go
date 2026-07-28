// Package thresholdagg implements quorum-gated plaintext aggregation.
//
// This is NOT fully homomorphic encryption (FHE) or any other cryptographic
// scheme: Update.Values are plain int64s, AggregateUpdates sums them in the
// clear, and RevealAggregate performs no decryption - it just copies the
// already-plaintext result out once a weighted quorum of participants is
// present. The only "protection" here is the quorum access-control check in
// HasQuorum, not confidentiality of the values themselves. This package
// exists as a placeholder for a possible future real threshold-FHE scheme
// (see docs/archive/root-cleanup-2026-04/UPGRADE_IMPLEMENTATION_PLAN_2026_2027.md)
// with the intended call shape (aggregate, then quorum-gated reveal) already
// in place. Do not rely on it for confidentiality.
package thresholdagg

import "fmt"

// Update is a contributor's plaintext value vector to be summed with others.
// The name deliberately avoids "encrypted"/"ciphertext": nothing here is
// encrypted, see the package doc comment.
type Update struct {
	Contributor string  `json:"contributor"`
	Values      []int64 `json:"values"`
}

// AggregateUpdates sums the Values vectors of all updates elementwise.
func AggregateUpdates(updates []Update) (Update, error) {
	if len(updates) == 0 {
		return Update{}, fmt.Errorf("no updates provided")
	}
	dim := len(updates[0].Values)
	if dim == 0 {
		return Update{}, fmt.Errorf("empty update vector")
	}
	acc := make([]int64, dim)
	for _, update := range updates {
		if len(update.Values) != dim {
			return Update{}, fmt.Errorf("mismatched update dimensions")
		}
		for i := range update.Values {
			acc[i] += update.Values[i]
		}
	}
	return Update{Contributor: "threshold-aggregate", Values: acc}, nil
}

// RevealAggregate returns the aggregate's plaintext values once the given
// participants meet the weighted quorum threshold. No decryption occurs -
// aggregate.Values is already plaintext; this only gates access to it.
func RevealAggregate(aggregate Update, participants []string, shares map[string]KeyShare, threshold int) ([]int64, error) {
	if !HasQuorum(participants, shares, threshold) {
		return nil, fmt.Errorf("insufficient key-share quorum")
	}
	out := make([]int64, len(aggregate.Values))
	copy(out, aggregate.Values)
	return out, nil
}
