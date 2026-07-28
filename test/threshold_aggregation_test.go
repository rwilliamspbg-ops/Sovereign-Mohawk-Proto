package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/thresholdagg"
)

func TestThresholdAggregateAndQuorumReveal(t *testing.T) {
	updates := []thresholdagg.Update{
		{Contributor: "a", Values: []int64{1, 2, 3}},
		{Contributor: "b", Values: []int64{2, 3, 4}},
	}
	agg, err := thresholdagg.AggregateUpdates(updates)
	if err != nil {
		t.Fatalf("aggregate: %v", err)
	}
	shares := []thresholdagg.KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "b", Weight: 1}, {NodeID: "c", Weight: 1}}
	if err := thresholdagg.ValidateShares(shares, 2); err != nil {
		t.Fatalf("validate shares: %v", err)
	}
	plain, err := thresholdagg.RevealAggregate(agg, []string{"a", "b"}, thresholdagg.ShareMap(shares), 2)
	if err != nil {
		t.Fatalf("reveal with quorum: %v", err)
	}
	if len(plain) != 3 || plain[0] != 3 || plain[1] != 5 || plain[2] != 7 {
		t.Fatalf("unexpected revealed aggregate: %#v", plain)
	}
	if _, err := thresholdagg.RevealAggregate(agg, []string{"a"}, thresholdagg.ShareMap(shares), 2); err == nil {
		t.Fatal("expected insufficient quorum to fail")
	}
}

func TestThresholdSerializationRoundTrip(t *testing.T) {
	update := thresholdagg.Update{Contributor: "node-x", Values: []int64{9, 8, 7}}
	raw, err := thresholdagg.MarshalUpdate(update)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	decoded, err := thresholdagg.UnmarshalUpdate(raw)
	if err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded.Contributor != update.Contributor || len(decoded.Values) != len(update.Values) {
		t.Fatalf("roundtrip mismatch: %#v", decoded)
	}
}
