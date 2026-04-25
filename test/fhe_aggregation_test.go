package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/fhe"
)

func TestFHEAggregateAndThresholdDecrypt(t *testing.T) {
	updates := []fhe.EncryptedUpdate{
		{Contributor: "a", Values: []int64{1, 2, 3}},
		{Contributor: "b", Values: []int64{2, 3, 4}},
	}
	agg, err := fhe.AggregateCiphertexts(updates)
	if err != nil {
		t.Fatalf("aggregate: %v", err)
	}
	shares := []fhe.KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "b", Weight: 1}, {NodeID: "c", Weight: 1}}
	if err := fhe.ValidateShares(shares, 2); err != nil {
		t.Fatalf("validate shares: %v", err)
	}
	plain, err := fhe.DecryptAggregate(agg, []string{"a", "b"}, fhe.ShareMap(shares), 2)
	if err != nil {
		t.Fatalf("decrypt with quorum: %v", err)
	}
	if len(plain) != 3 || plain[0] != 3 || plain[1] != 5 || plain[2] != 7 {
		t.Fatalf("unexpected decrypted aggregate: %#v", plain)
	}
	if _, err := fhe.DecryptAggregate(agg, []string{"a"}, fhe.ShareMap(shares), 2); err == nil {
		t.Fatal("expected insufficient quorum to fail")
	}
}

func TestFHESerializationRoundTrip(t *testing.T) {
	update := fhe.EncryptedUpdate{Contributor: "node-x", Values: []int64{9, 8, 7}}
	raw, err := fhe.MarshalUpdate(update)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	decoded, err := fhe.UnmarshalUpdate(raw)
	if err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded.Contributor != update.Contributor || len(decoded.Values) != len(update.Values) {
		t.Fatalf("roundtrip mismatch: %#v", decoded)
	}
}
