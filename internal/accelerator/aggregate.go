// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package accelerator

import (
	"fmt"
	"math"
	"runtime"
	"sync"
)

// AggregateParallel sums a batch of same-length float32 gradient vectors in
// parallel, divides by the number of gradients, then applies ℓ₂ clipping to
// maxNorm (per Theorem 3 – differential privacy sensitivity bound).
//
// workers ≤ 0 defaults to GOMAXPROCS, which is automatically tuned to SIMD
// parallelism by the Go scheduler on CPU backends. On GPU/NPU backends
// callers should pass the physical thread count reported by DeviceInfo.
func AggregateParallel(gradients [][]float32, maxNorm float64, workers int) ([]float32, error) {
	if len(gradients) == 0 {
		return nil, nil
	}
	dim := len(gradients[0])
	for i, g := range gradients {
		if len(g) != dim {
			return nil, fmt.Errorf("gradient %d has length %d, expected %d", i, len(g), dim)
		}
	}
	if workers <= 0 {
		workers = runtime.GOMAXPROCS(0)
	}
	if workers > len(gradients) {
		workers = len(gradients)
	}

	// Reduce: sum all gradient vectors using parallel partial sums.
	sum := make([]float32, dim)
	var (
		mu sync.Mutex
		wg sync.WaitGroup
	)
	chunkSize := (len(gradients) + workers - 1) / workers
	for w := 0; w < workers; w++ {
		start := w * chunkSize
		end := start + chunkSize
		if end > len(gradients) {
			end = len(gradients)
		}
		if start >= end {
			break
		}
		wg.Add(1)
		go func(slice [][]float32) {
			defer wg.Done()
			local := make([]float32, dim)
			for _, grad := range slice {
				for i, v := range grad {
					local[i] += v
				}
			}
			mu.Lock()
			for i := range local {
				sum[i] += local[i]
			}
			mu.Unlock()
		}(gradients[start:end])
	}
	wg.Wait()

	// Average.
	count := float32(len(gradients))
	for i := range sum {
		sum[i] /= count
	}

	// ℓ₂ clipping per Theorem 3 DP sensitivity bound.
	if maxNorm > 0 {
		l2Clip(sum, maxNorm)
	}
	return sum, nil
}

// l2Clip scales v in-place so ‖v‖₂ ≤ maxNorm.
func l2Clip(v []float32, maxNorm float64) {
	var norm float64
	for _, x := range v {
		norm += float64(x) * float64(x)
	}
	norm = math.Sqrt(norm)
	if norm > maxNorm {
		scale := float32(maxNorm / norm)
		for i := range v {
			v[i] *= scale
		}
	}
}

// L2Norm returns the ℓ₂ norm of the vector v.
func L2Norm(v []float32) float64 {
	var sum float64
	for _, x := range v {
		sum += float64(x) * float64(x)
	}
	return math.Sqrt(sum)
}
