## 2026-07-09 - Go Allocation & Math Monotonicity Optimizations
**Learning:** High-throughput Go federated learning engines suffer from GC pressure and CPU overhead under frequent batch updates. We can dramatically optimize performance by:
1. Reusing row slice buffers sequentially across loop iterations rather than allocating them repeatedly inside the loop.
2. Flattening 2D slices (`[][]float64`) into contiguous 1D slices (`[]float64`) to require exactly 1 heap allocation instead of N+1, which is also extremely CPU cache-friendly.
3. Leveraging the monotonicity of the square root function to perform sorting and comparative operations on raw squared values (e.g., squared L2 norms), bypassing expensive `math.Sqrt` calculations completely in O(N) operations.
**Action:** Always inspect loops and matrices on Go hot paths for flat slice optimizations, pre-allocated buffer reuse, and mathematical monotonicity opportunities to minimize GC activity and CPU execution times.
