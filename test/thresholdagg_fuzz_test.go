package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/thresholdagg"
)

func FuzzThresholdAggUnmarshal(f *testing.F) {
	f.Add([]byte(`{"contributor":"a","values":[1,2,3]}`))
	f.Add([]byte(`{}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		u, err := thresholdagg.UnmarshalUpdate(data)
		if err != nil {
			return
		}
		b, err := thresholdagg.MarshalUpdate(u)
		if err != nil {
			t.Fatalf("marshal failed: %v", err)
		}
		u2, err := thresholdagg.UnmarshalUpdate(b)
		if err != nil {
			t.Fatalf("round-trip unmarshal failed: %v", err)
		}
		if u.Contributor != u2.Contributor {
			t.Fatalf("contributor mismatch: %q vs %q", u.Contributor, u2.Contributor)
		}
		if len(u.Values) != len(u2.Values) {
			t.Fatalf("values len mismatch: %d vs %d", len(u.Values), len(u2.Values))
		}
		for i := range u.Values {
			if u.Values[i] != u2.Values[i] {
				t.Fatalf("value mismatch at %d", i)
			}
		}
	})
}
