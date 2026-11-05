# Streaming Aggregator

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. What is implemented

Accepts unordered gradient chunks instead of full tensors, reassembles them, and aggregates.

- Implementation: `internal/streaming_aggregator.go`.
- Types: `ChunkAssembly`, `StreamingAggregator`, `StreamingAggregatorOptions`.

## 2. How it works

1. Chunks arrive out of order (transport may spray across paths).
2. `ChunkAssembly` buffers chunks keyed by index until all `total` chunks arrive or timeout.
3. Assembled tensor forwarded to the aggregation path (Multi-Krum when `EnableByzantine` is set).
4. Timeouts and buffer limits configurable via `StreamingAggregatorOptions` (`MaxBufferedTensors`, `TensorTimeoutSec`, `CheckpointInterval`).

## 3. Configuration

- `StreamingAggregatorOptions` fields listed above.
- Tests: `internal/streaming_aggregator_test.go`.

## 4. Cross-references

- Transport: `docs/architecture/TRANSPORT_LAYER.md`
- Byzantine resilience: `docs/architecture/BYZANTINE_RESILIENCE.md`
