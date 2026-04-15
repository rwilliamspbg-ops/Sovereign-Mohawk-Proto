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
	"os"
	"runtime"
	"strconv"
	"sync"
)

const autoParallelMinElements = 262144

var (
	aggregateWorkersMu      sync.Mutex
	aggregateWorkersByShape = map[uint64]int{}
	partialBufferPool       sync.Pool
)

type partialBuffer struct {
	buf []float32
}

// ResolveAggregateWorkers determines the worker count used by AggregateParallel.
//
// If requestedWorkers > 0, the value is clamped to [1, numGradients].
// If requestedWorkers <= 0, a heuristic chooses between single-threaded and
// parallel execution to avoid overhead on small reductions.
func ResolveAggregateWorkers(numGradients int, dim int, requestedWorkers int) int {
	if numGradients <= 0 {
		return 1
	}

	if requestedWorkers > 0 {
		if requestedWorkers > numGradients {
			return numGradients
		}
		return requestedWorkers
	}

	totalElements := numGradients * dim
	if totalElements < autoParallelMinElements || numGradients < 4 {
		return 1
	}

	workers := runtime.GOMAXPROCS(0)
	queueDepth := readPositiveIntEnv("MOHAWK_AGGREGATE_QUEUE_DEPTH")
	if queueDepth > 0 {
		// Increase pressure response gradually when backlog grows.
		workers += queueDepth / 4
	}
	if workers < 1 {
		workers = 1
	}
	if workers > numGradients {
		workers = numGradients
	}

	shape := (uint64(uint32(numGradients)) << 32) | uint64(uint32(dim))
	aggregateWorkersMu.Lock()
	if prev, ok := aggregateWorkersByShape[shape]; ok {
		if workers > prev+1 {
			workers = prev + 1
		} else if workers < prev-1 {
			workers = prev - 1
		}
	}
	aggregateWorkersByShape[shape] = workers
	aggregateWorkersMu.Unlock()

	return workers
}

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
	workers = ResolveAggregateWorkers(len(gradients), dim, workers)

	// Reduce: each worker builds a private partial sum, then we merge once.
	sum := make([]float32, dim)
	partials := make([][]float32, workers)
	var wg sync.WaitGroup
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
		partials[w] = acquirePartialBuffer(dim)
		wg.Add(1)
		go func(slice [][]float32, local []float32) {
			defer wg.Done()
			for _, grad := range slice {
				accumulateUnrolled(local, grad)
			}
		}(gradients[start:end], partials[w])
	}
	wg.Wait()

	for _, partial := range partials {
		if partial == nil {
			continue
		}
		accumulateUnrolled(sum, partial)
		releasePartialBuffer(partial)
	}

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

// accumulateUnrolled adds src into dst with loop unrolling to reduce overhead
// in large-dimensional FedAvg reduction loops.
func accumulateUnrolled(dst []float32, src []float32) {
	i := 0
	n := len(dst)
	for ; i+3 < n; i += 4 {
		dst[i] += src[i]
		dst[i+1] += src[i+1]
		dst[i+2] += src[i+2]
		dst[i+3] += src[i+3]
	}
	for ; i < n; i++ {
		dst[i] += src[i]
	}
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

func acquirePartialBuffer(dim int) []float32 {
	if pb, ok := partialBufferPool.Get().(*partialBuffer); ok && pb != nil {
		if cap(pb.buf) >= dim {
			pb.buf = pb.buf[:dim]
			for i := range pb.buf {
				pb.buf[i] = 0
			}
			return pb.buf
		}
	}
	return make([]float32, dim)
}

func releasePartialBuffer(buf []float32) {
	if buf == nil {
		return
	}
	partialBufferPool.Put(&partialBuffer{buf: buf})
}

func readPositiveIntEnv(key string) int {
	raw := os.Getenv(key)
	if raw == "" {
		return 0
	}
	v, err := strconv.Atoi(raw)
	if err != nil || v <= 0 {
		return 0
	}
	return v
}
