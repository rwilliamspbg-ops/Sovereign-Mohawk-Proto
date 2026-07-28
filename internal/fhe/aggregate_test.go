package fhe

import "testing"

// NOTE on scope: as implemented, EncryptedUpdate.Values are plain int64s and
// AggregateCiphertexts/DecryptAggregate perform ordinary integer arithmetic
// -- there is no actual homomorphic encryption, key generation, or
// ciphertext transformation anywhere in this package (see keys_test.go and
// the package-level finding recorded there). These tests therefore verify
// the *additive aggregation* contract this package actually implements
// (sum-of-plaintext-vectors plus a quorum gate on release), not FHE
// round-trip correctness in the cryptographic sense, since no encryption
// exists to round-trip.

func TestAggregateCiphertexts_EmptyUpdatesErrors(t *testing.T) {
	if _, err := AggregateCiphertexts(nil); err == nil {
		t.Fatal("expected empty updates slice to fail")
	}
	if _, err := AggregateCiphertexts([]EncryptedUpdate{}); err == nil {
		t.Fatal("expected empty updates slice to fail")
	}
}

func TestAggregateCiphertexts_EmptyVectorErrors(t *testing.T) {
	updates := []EncryptedUpdate{{Contributor: "a", Values: []int64{}}}
	if _, err := AggregateCiphertexts(updates); err == nil {
		t.Fatal("expected an empty ciphertext vector to fail")
	}
}

func TestAggregateCiphertexts_MismatchedDimensionsErrors(t *testing.T) {
	updates := []EncryptedUpdate{
		{Contributor: "a", Values: []int64{1, 2, 3}},
		{Contributor: "b", Values: []int64{1, 2}},
	}
	if _, err := AggregateCiphertexts(updates); err == nil {
		t.Fatal("expected mismatched dimensions to fail")
	}
}

func TestAggregateCiphertexts_MatchesPlaintextSum(t *testing.T) {
	tests := []struct {
		name    string
		updates []EncryptedUpdate
		want    []int64
	}{
		{
			name: "two contributors positive values",
			updates: []EncryptedUpdate{
				{Contributor: "a", Values: []int64{1, 2, 3}},
				{Contributor: "b", Values: []int64{2, 3, 4}},
			},
			want: []int64{3, 5, 7},
		},
		{
			name: "single contributor is identity",
			updates: []EncryptedUpdate{
				{Contributor: "solo", Values: []int64{9, 8, 7}},
			},
			want: []int64{9, 8, 7},
		},
		{
			name: "negative and positive values cancel",
			updates: []EncryptedUpdate{
				{Contributor: "a", Values: []int64{10, -10, 5}},
				{Contributor: "b", Values: []int64{-10, 10, -5}},
			},
			want: []int64{0, 0, 0},
		},
		{
			name: "many contributors single dimension",
			updates: []EncryptedUpdate{
				{Contributor: "a", Values: []int64{1}},
				{Contributor: "b", Values: []int64{1}},
				{Contributor: "c", Values: []int64{1}},
				{Contributor: "d", Values: []int64{1}},
			},
			want: []int64{4},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			agg, err := AggregateCiphertexts(tt.updates)
			if err != nil {
				t.Fatalf("aggregate failed: %v", err)
			}
			if len(agg.Values) != len(tt.want) {
				t.Fatalf("expected %d dims, got %d", len(tt.want), len(agg.Values))
			}
			for i := range tt.want {
				if agg.Values[i] != tt.want[i] {
					t.Fatalf("dim %d: expected %d, got %d (full: %#v)", i, tt.want[i], agg.Values[i], agg.Values)
				}
			}
			if agg.Contributor != "threshold-aggregate" {
				t.Fatalf("expected aggregate contributor label 'threshold-aggregate', got %q", agg.Contributor)
			}
		})
	}
}

func TestAggregateCiphertexts_DoesNotMutateInputs(t *testing.T) {
	a := EncryptedUpdate{Contributor: "a", Values: []int64{1, 2, 3}}
	b := EncryptedUpdate{Contributor: "b", Values: []int64{4, 5, 6}}
	updates := []EncryptedUpdate{a, b}
	if _, err := AggregateCiphertexts(updates); err != nil {
		t.Fatalf("aggregate failed: %v", err)
	}
	if updates[0].Values[0] != 1 || updates[1].Values[0] != 4 {
		t.Fatal("aggregation must not mutate the input updates")
	}
}

// --- DecryptAggregate ---------------------------------------------------------

func TestDecryptAggregate_InsufficientQuorumErrors(t *testing.T) {
	agg := EncryptedUpdate{Contributor: "threshold-aggregate", Values: []int64{1, 2, 3}}
	shares := ShareMap([]KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "b", Weight: 1}})
	if _, err := DecryptAggregate(agg, []string{"a"}, shares, 2); err == nil {
		t.Fatal("expected insufficient quorum to fail")
	}
}

func TestDecryptAggregate_QuorumMetReturnsValues(t *testing.T) {
	agg := EncryptedUpdate{Contributor: "threshold-aggregate", Values: []int64{3, 5, 7}}
	shares := ShareMap([]KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "b", Weight: 1}, {NodeID: "c", Weight: 1}})
	out, err := DecryptAggregate(agg, []string{"a", "b"}, shares, 2)
	if err != nil {
		t.Fatalf("decrypt with quorum failed: %v", err)
	}
	if len(out) != 3 || out[0] != 3 || out[1] != 5 || out[2] != 7 {
		t.Fatalf("unexpected decrypted values: %#v", out)
	}
}

func TestDecryptAggregate_ReturnsIndependentCopy(t *testing.T) {
	agg := EncryptedUpdate{Contributor: "threshold-aggregate", Values: []int64{1, 2, 3}}
	shares := ShareMap([]KeyShare{{NodeID: "a", Weight: 1}})
	out, err := DecryptAggregate(agg, []string{"a"}, shares, 1)
	if err != nil {
		t.Fatalf("decrypt failed: %v", err)
	}
	out[0] = 999
	if agg.Values[0] != 1 {
		t.Fatal("mutating decrypted output must not mutate the original aggregate")
	}
}

func TestDecryptAggregate_ZeroThresholdAlwaysFails(t *testing.T) {
	agg := EncryptedUpdate{Contributor: "threshold-aggregate", Values: []int64{1}}
	shares := ShareMap([]KeyShare{{NodeID: "a", Weight: 100}})
	if _, err := DecryptAggregate(agg, []string{"a"}, shares, 0); err == nil {
		t.Fatal("expected zero/invalid threshold to fail closed")
	}
}

// --- end-to-end: aggregate then decrypt matches a manual plaintext sum -------

func TestAggregateThenDecrypt_EndToEndMatchesPlaintextSum(t *testing.T) {
	updates := []EncryptedUpdate{
		{Contributor: "node-1", Values: []int64{10, -3, 100}},
		{Contributor: "node-2", Values: []int64{-5, 7, 50}},
		{Contributor: "node-3", Values: []int64{1, 1, 1}},
	}
	// manual plaintext expectation
	want := []int64{10 - 5 + 1, -3 + 7 + 1, 100 + 50 + 1}

	agg, err := AggregateCiphertexts(updates)
	if err != nil {
		t.Fatalf("aggregate failed: %v", err)
	}
	shares := ShareMap([]KeyShare{{NodeID: "node-1", Weight: 1}, {NodeID: "node-2", Weight: 1}, {NodeID: "node-3", Weight: 1}})
	out, err := DecryptAggregate(agg, SortedParticipants([]string{"node-1", "node-2", "node-3"}), shares, 3)
	if err != nil {
		t.Fatalf("decrypt failed: %v", err)
	}
	for i := range want {
		if out[i] != want[i] {
			t.Fatalf("dim %d: expected %d, got %d", i, want[i], out[i])
		}
	}
}
