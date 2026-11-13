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

// FuzzThresholdAggAggregate asserts the additive aggregation contract:
// dimension is preserved, mismatched/empty vectors are rejected, and the
// result is exactly the elementwise sum.
func FuzzThresholdAggAggregate(f *testing.F) {
	f.Add([]byte(`{"contributor":"a","values":[1,2,3]}`), []byte(`{"contributor":"b","values":[4,5,6]}`))
	f.Add([]byte(`{"contributor":"a","values":[1,2,3]}`), []byte(`{"contributor":"b","values":[4,5]}`))
	f.Add([]byte(`{"contributor":"a","values":[]}`), []byte(`{"contributor":"b","values":[4,5,6]}`))
	f.Add([]byte(`{}`), []byte(`{}`))
	f.Fuzz(func(t *testing.T, aData, bData []byte) {
		a, errA := thresholdagg.UnmarshalUpdate(aData)
		b, errB := thresholdagg.UnmarshalUpdate(bData)
		if errA != nil || errB != nil {
			return
		}
		agg, err := thresholdagg.AggregateUpdates([]thresholdagg.Update{a, b})
		if err != nil {
			// Allowed failures: empty vector or mismatched dimensions.
			if len(a.Values) == 0 || len(b.Values) == 0 || len(a.Values) != len(b.Values) {
				return
			}
			t.Fatalf("unexpected aggregate error: %v", err)
			return
		}
		if len(agg.Values) != len(a.Values) {
			t.Fatalf("aggregate dimension %d != input %d", len(agg.Values), len(a.Values))
		}
		for i := range agg.Values {
			if agg.Values[i] != a.Values[i]+b.Values[i] {
				t.Fatalf("aggregate[%d]=%d, want %d", i, agg.Values[i], a.Values[i]+b.Values[i])
			}
		}
	})
}
