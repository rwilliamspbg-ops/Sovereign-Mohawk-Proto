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
		_, _ = thresholdagg.MarshalUpdate(u)
	})
}
