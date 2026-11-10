package accelerator

import (
	"math"
	"testing"
)

// FuzzAggregateParallel checks basic invariants of the aggregation kernel:
// - output length equals input dimension
// - no NaN/Inf in output
// - result is finite
func FuzzAggregateParallel(f *testing.F) {
	f.Add(2, 4)
	f.Fuzz(func(t *testing.T, n, dim int) {
		if n <= 0 || dim <= 0 || n > 16 || dim > 16 {
			t.Skip()
		}
		grads := make([][]float32, n)
		for i := range grads {
			grads[i] = make([]float32, dim)
			for j := range grads[i] {
				grads[i][j] = float32(i+j) * 0.5
			}
		}
		out, err := AggregateParallel(grads, 10.0, 1)
		if err != nil {
			t.Fatal(err)
		}
		if len(out) != dim {
			t.Fatalf("len=%d want %d", len(out), dim)
		}
		for _, v := range out {
			if math.IsNaN(float64(v)) || math.IsInf(float64(v), 0) {
				t.Fatalf("non-finite output %v", v)
			}
		}
	})
}