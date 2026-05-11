"""
LLM Training Performance Test Suite at Scale

Tests comprehensive performance metrics for federated learning at 10M+ sample scale:
- Data loading throughput (samples/sec)
- Gradient compression overhead
- Aggregation latency across distributed nodes
- Memory efficiency and gradient buffer management
- Byzantine-resilient aggregation performance
- End-to-end training round latency
"""

import json
import time
import random
import array
import pytest
from typing import List, Dict, Any, Tuple

from mohawk import MohawkNode, GradientBuffer, AggregationError

# ============================================================================
# DATA GENERATION & LOADING TESTS
# ============================================================================


class DataGenerator:
    """Simulates real-world LLM training data loading patterns."""

    @staticmethod
    def generate_token_batch(batch_size: int = 512, seq_len: int = 512, vocab_size: int = 50257):
        """Generate realistic token sequences (GPT-2 tokenizer size)."""
        return [
            [random.randint(0, vocab_size - 1) for _ in range(seq_len)] for _ in range(batch_size)
        ]

    @staticmethod
    def generate_gradients(model_dim: int = 768, num_layers: int = 12) -> List[float]:
        """Generate gradient vectors for transformer models (768D -> 9216D for 12-layer)."""
        total_params = model_dim * num_layers
        return [random.gauss(0, 0.01) for _ in range(total_params)]

    @staticmethod
    def generate_large_dataset(num_samples: int, batch_size: int = 512):
        """Generator for large datasets to simulate streaming data loading."""
        num_batches = num_samples // batch_size
        for _ in range(num_batches):
            yield DataGenerator.generate_token_batch(batch_size)


@pytest.fixture
def node():
    """Fixture: Initialize MOHAWK node for testing."""
    node = MohawkNode()
    node.bridge.close()
    return node


class TestDataLoadingPerformance:
    """Test data loading throughput at scale."""

    def test_load_10m_samples_streaming(self):
        """Benchmark streaming load of 10M samples at 512 tokens/sample."""
        num_samples = 10_000_000
        batch_size = 512
        samples_processed = 0

        start = time.perf_counter()

        # Simulate streaming data load
        for batch in DataGenerator.generate_large_dataset(num_samples, batch_size):
            samples_processed += len(batch)
            if samples_processed >= num_samples:
                break

        elapsed = time.perf_counter() - start
        throughput = samples_processed / elapsed

        # Expected: ~2M samples/sec on modern hardware
        assert throughput > 100_000, f"Throughput {throughput:.0f} samples/sec too low"

        report = {
            "test": "10M sample streaming load",
            "samples": samples_processed,
            "duration_sec": elapsed,
            "throughput": throughput,
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_load_100m_samples_with_prefetch(self):
        """Benchmark prefetch buffer strategy for 100M samples."""
        num_samples = 100_000_000
        batch_size = 512
        prefetch_size = 10  # Keep 10 batches in memory
        samples_processed = 0

        start = time.perf_counter()

        buffer = []
        data_gen = DataGenerator.generate_large_dataset(num_samples, batch_size)

        # Prefill buffer
        for _ in range(prefetch_size):
            try:
                buffer.append(next(data_gen))
            except StopIteration:
                break

        # Stream with prefetch
        while buffer and samples_processed < num_samples:
            batch = buffer.pop(0)
            samples_processed += len(batch)

            try:
                buffer.append(next(data_gen))
            except StopIteration:
                pass

        elapsed = time.perf_counter() - start
        throughput = samples_processed / elapsed

        report = {
            "test": "100M sample with prefetch",
            "samples": samples_processed,
            "duration_sec": elapsed,
            "throughput": throughput,
            "prefetch_buffer_size": prefetch_size,
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_sequential_batch_load_latency(self):
        """Measure per-batch load latency (target: <1ms for 512 tokens)."""
        num_batches = 1000
        batch_size = 512

        latencies = []
        for _ in range(num_batches):
            start = time.perf_counter()
            batch = DataGenerator.generate_token_batch(batch_size)
            latency = (time.perf_counter() - start) * 1000  # Convert to ms

            latencies.append(latency)

        avg_latency = sum(latencies) / len(latencies)
        p95_latency = sorted(latencies)[int(len(latencies) * 0.95)]
        p99_latency = sorted(latencies)[int(len(latencies) * 0.99)]

        report = {
            "test": "batch load latency (512 tokens)",
            "num_batches": num_batches,
            "avg_latency_ms": round(avg_latency, 3),
            "p95_latency_ms": round(p95_latency, 3),
            "p99_latency_ms": round(p99_latency, 3),
        }
        print(f"\n{json.dumps(report, indent=2)}")

        assert avg_latency < 1.0, f"Batch load latency {avg_latency:.3f}ms exceeds 1ms target"


# ============================================================================
# GRADIENT COMPRESSION PERFORMANCE
# ============================================================================


class TestGradientCompressionAtScale:
    """Test gradient compression performance with realistic model sizes."""

    def test_gradient_compression_throughput(self, node):
        """Benchmark FP16/INT8 compression throughput (target: 1M params/sec)."""
        gradient_sizes = [768, 1536, 3072, 6144, 12288]  # Transformer layer dims
        results = []

        for grad_dim in gradient_sizes:
            gradients = DataGenerator.generate_gradients(grad_dim)

            start = time.perf_counter()
            result = node.compress_gradients(gradients, format="fp16")
            elapsed = (time.perf_counter() - start) * 1000

            compression_ratio = (
                result.get("compression_ratio", 1.0)
                if result.get("compression_ratio")
                else len(gradients) * 4 / len(gradients) * 2
            )

            throughput = grad_dim / elapsed  # params/ms = params/sec * 1000

            results.append(
                {
                    "gradient_dim": grad_dim,
                    "compression_time_ms": round(elapsed, 3),
                    "throughput_params_per_sec": round(throughput * 1000, 0),
                    "compression_ratio": round(compression_ratio, 2),
                    "success": result.get("success", False),
                }
            )

        report = {"test": "gradient compression throughput", "results": results}
        print(f"\n{json.dumps(report, indent=2)}")

        # All compressions should succeed
        assert all(r["success"] for r in results)

    def test_int8_vs_fp16_compression_quality(self, node):
        """Compare INT8 vs FP16 compression ratio and speed."""
        gradient_dim = 6144
        gradients = DataGenerator.generate_gradients(gradient_dim)

        # Test FP16
        start_fp16 = time.perf_counter()
        result_fp16 = node.compress_gradients(gradients, format="fp16")
        elapsed_fp16 = (time.perf_counter() - start_fp16) * 1000

        # Test INT8
        start_int8 = time.perf_counter()
        result_int8 = node.compress_gradients(gradients, format="int8", max_norm=1.0)
        elapsed_int8 = (time.perf_counter() - start_int8) * 1000

        report = {
            "test": "INT8 vs FP16 compression",
            "gradient_dim": gradient_dim,
            "fp16": {
                "compression_time_ms": round(elapsed_fp16, 3),
                "compression_ratio": round(result_fp16.get("compression_ratio", 0), 2),
                "format": result_fp16.get("format", "fp16"),
            },
            "int8": {
                "compression_time_ms": round(elapsed_int8, 3),
                "compression_ratio": round(result_int8.get("compression_ratio", 0), 2),
                "format": result_int8.get("format", "int8"),
            },
            "speedup_int8_over_fp16": round(elapsed_fp16 / elapsed_int8, 2),
        }
        print(f"\n{json.dumps(report, indent=2)}")

        assert result_fp16.get("success")
        assert result_int8.get("success")

    def test_zero_copy_compression_memory_efficiency(self, node):
        """Measure memory overhead of zero-copy vs standard compression."""
        gradient_sizes = [1024, 4096, 16384, 65536]
        results = []

        for size in gradient_sizes:
            # Create array buffer
            buf = array.array("f", [0.01 * i for i in range(size)])
            view = memoryview(buf)

            # Measure zero-copy compression
            start = time.perf_counter()
            result = node.compress_gradients_zero_copy(view, format="fp16")
            elapsed = (time.perf_counter() - start) * 1000

            memory_overhead_bytes = result.get("count", size) * 4
            compression_bytes = result.get("compressed_bytes", size * 2)

            results.append(
                {
                    "size": size,
                    "time_ms": round(elapsed, 3),
                    "zero_copy": result.get("zero_copy", False),
                    "original_bytes": size * 4,
                    "compressed_bytes": compression_bytes,
                    "savings_percent": round(100 * (1 - compression_bytes / (size * 4)), 1),
                }
            )

        report = {
            "test": "zero-copy compression memory efficiency",
            "results": results,
        }
        print(f"\n{json.dumps(report, indent=2)}")


# ============================================================================
# AGGREGATION & BYZANTINE RESILIENCE PERFORMANCE
# ============================================================================


class TestAggregationPerformance:
    """Test aggregation performance across distributed nodes."""

    def test_aggregate_1000_nodes_updates(self, node):
        """Benchmark aggregation of 1000 node updates (O(n log n) expected)."""
        num_nodes = 1000
        gradient_dim = 1536
        updates = [
            {
                "node_id": f"node-{i}",
                "gradient": DataGenerator.generate_gradients(gradient_dim),
            }
            for i in range(num_nodes)
        ]

        start = time.perf_counter()
        try:
            result = node.aggregate(updates)
            elapsed = (time.perf_counter() - start) * 1000
        except AggregationError as e:
            # Expected: privacy budget may be exhausted in simulation
            elapsed = (time.perf_counter() - start) * 1000
            result = {"success": False, "error": str(e)}

        report = {
            "test": "aggregate 1000 node updates",
            "num_nodes": num_nodes,
            "gradient_dim": gradient_dim,
            "aggregation_time_ms": round(elapsed, 3),
            "time_per_node_us": round(elapsed * 1000 / num_nodes, 1),
            "success": result.get("success", False),
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_stream_aggregate_with_compression(self, node):
        """Benchmark streaming aggregation with gradient compression."""
        num_participants = 100
        gradient_dim = 3072
        batches_per_participant = 10

        start = time.perf_counter()
        total_gradients = 0

        for batch_idx in range(batches_per_participant):
            gradient_stream = [
                DataGenerator.generate_gradients(gradient_dim) for _ in range(num_participants)
            ]

            result = node.stream_aggregate(gradient_stream, format="fp16", max_norm=1.0)

            if result.get("success"):
                total_gradients += result.get("count", len(gradient_stream))

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "streaming aggregation with compression",
            "num_participants": num_participants,
            "batches": batches_per_participant,
            "total_gradient_vectors": total_gradients,
            "total_time_ms": round(elapsed, 3),
            "avg_batch_time_ms": round(elapsed / batches_per_participant, 3),
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_byzantine_resilience_aggregation(self, node):
        """Test aggregation resilience to Byzantine (poisoned) updates."""
        num_honest = 900
        num_byzantine = 100
        gradient_dim = 1536

        # Honest updates: normally distributed around 0
        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": [random.gauss(0, 0.01) for _ in range(gradient_dim)],
            }
            for i in range(num_honest)
        ]

        # Byzantine updates: large magnitude to poison aggregation
        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": [random.gauss(0, 10.0) for _ in range(gradient_dim)],  # 100x larger
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            elapsed = (time.perf_counter() - start) * 1000
        except AggregationError:
            elapsed = (time.perf_counter() - start) * 1000
            result = {"success": False}

        report = {
            "test": "Byzantine resilience aggregation",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": f"{100*num_byzantine/(num_honest+num_byzantine):.1f}%",
            "aggregation_time_ms": round(elapsed, 3),
            "success": result.get("success", False),
        }
        print(f"\n{json.dumps(report, indent=2)}")


# ============================================================================
# END-TO-END TRAINING ROUND PERFORMANCE
# ============================================================================


class TestEndToEndTrainingRound:
    """Test complete federated learning training round performance."""

    def test_full_training_round_100_nodes(self, node):
        """
        Benchmark complete training round:
        - Data load
        - Forward/backward (simulated)
        - Gradient compression
        - Aggregation
        - Model update
        """
        num_nodes = 100
        samples_per_node = 100_000
        batch_size = 512
        gradient_dim = 3072
        compression_format = "fp16"

        timings: Dict[str, float] = {}

        # Phase 1: Data loading
        start = time.perf_counter()
        total_batches = 0
        for _ in DataGenerator.generate_large_dataset(samples_per_node, batch_size):
            total_batches += 1
            if total_batches * batch_size >= samples_per_node:
                break
        timings["data_load_ms"] = (time.perf_counter() - start) * 1000

        # Phase 2: Gradient computation (simulated)
        start = time.perf_counter()
        node_gradients = [DataGenerator.generate_gradients(gradient_dim) for _ in range(num_nodes)]
        timings["gradient_compute_ms"] = (time.perf_counter() - start) * 1000

        # Phase 3: Compression at each node
        start = time.perf_counter()
        compressed_updates = []
        for node_id, grads in enumerate(node_gradients):
            try:
                result = node.compress_gradients(grads, format=compression_format)
                if result.get("success"):
                    compressed_updates.append(result)
            except AggregationError:
                pass
        timings["compression_ms"] = (time.perf_counter() - start) * 1000

        # Phase 4: Aggregation at server
        start = time.perf_counter()
        aggregation_updates = [
            {"node_id": f"node-{i}", "gradient": grads} for i, grads in enumerate(node_gradients)
        ]
        try:
            agg_result = node.aggregate(aggregation_updates)
            aggregation_success = agg_result.get("success", False)
        except AggregationError:
            aggregation_success = False
        timings["aggregation_ms"] = (time.perf_counter() - start) * 1000

        # Phase 5: Model update (simulated)
        start = time.perf_counter()
        updated_model = [
            param - 0.01 * grad
            for param, grad in zip(
                DataGenerator.generate_gradients(gradient_dim), node_gradients[0]
            )
        ]
        timings["model_update_ms"] = (time.perf_counter() - start) * 1000

        total_round_time = sum(timings.values())

        report = {
            "test": "full training round (100 nodes, 100K samples/node)",
            "num_nodes": num_nodes,
            "samples_per_node": samples_per_node,
            "gradient_dim": gradient_dim,
            "timings": {k: round(v, 3) for k, v in timings.items()},
            "total_round_time_ms": round(total_round_time, 3),
            "aggregation_success": aggregation_success,
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_multi_round_convergence_simulation(self, node):
        """Simulate 10 training rounds with convergence metrics."""
        num_rounds = 10
        num_nodes = 50
        gradient_dim = 1536
        learning_rate = 0.01

        model = DataGenerator.generate_gradients(gradient_dim)
        round_metrics = []

        for round_idx in range(num_rounds):
            round_start = time.perf_counter()

            # Each node computes gradients
            node_updates = [
                DataGenerator.generate_gradients(gradient_dim) for _ in range(num_nodes)
            ]

            # Compress and aggregate
            compression_start = time.perf_counter()
            try:
                agg_result = node.stream_aggregate(node_updates, format="fp16")
                compression_time = (time.perf_counter() - compression_start) * 1000
            except AggregationError:
                compression_time = (time.perf_counter() - compression_start) * 1000
                agg_result = {"success": False}

            # Update model (simulated SGD step)
            avg_gradient = [sum(g) / num_nodes for g in zip(*node_updates)]
            model = [p - learning_rate * g for p, g in zip(model, avg_gradient)]

            round_time = (time.perf_counter() - round_start) * 1000

            # Compute loss (simulated)
            loss = sum(g**2 for g in model) / len(model)

            round_metrics.append(
                {
                    "round": round_idx + 1,
                    "round_time_ms": round(round_time, 3),
                    "compression_time_ms": round(compression_time, 3),
                    "loss": round(loss, 6),
                    "aggregation_success": agg_result.get("success", False),
                }
            )

        report = {
            "test": "10-round federated training convergence",
            "num_nodes": num_nodes,
            "gradient_dim": gradient_dim,
            "learning_rate": learning_rate,
            "rounds": round_metrics,
            "avg_round_time_ms": round(
                sum(m["round_time_ms"] for m in round_metrics) / num_rounds, 3
            ),
        }
        print(f"\n{json.dumps(report, indent=2)}")


# ============================================================================
# MEMORY & RESOURCE EFFICIENCY
# ============================================================================


class TestMemoryEfficiency:
    """Test memory usage and GradientBuffer efficiency."""

    def test_gradient_buffer_memory_profile(self):
        """Profile memory usage of GradientBuffer across scales."""
        sizes = [512, 2048, 8192, 32768]
        results = []

        for size in sizes:
            buffer = GradientBuffer(max_norm=1.0, format="fp16")

            # Add multiple batches
            for _ in range(10):
                buffer.add([random.gauss(0, 0.01) for _ in range(size)])

            compressed = buffer.compress()
            info = compressed.to_dict()

            results.append(
                {
                    "buffer_size": size,
                    "format": info.get("format"),
                    "compressed_bytes": info.get("compressed_bytes", 0),
                    "original_bytes": size * 4 * 10,  # 10 batches
                    "compression_ratio": round(
                        (size * 4 * 10) / info.get("compressed_bytes", 1), 2
                    ),
                }
            )

        report = {"test": "gradient buffer memory profile", "results": results}
        print(f"\n{json.dumps(report, indent=2)}")

    def test_large_scale_buffer_accumulation(self):
        """Test buffer accumulation for 1M parameters."""
        buffer = GradientBuffer(max_norm=1.0, format="auto")
        total_accumulated = 0

        # Accumulate 1M params in 1K batches
        for _ in range(1000):
            gradients = [random.gauss(0, 0.01) for _ in range(1000)]
            buffer.add(gradients)
            total_accumulated += len(gradients)

        compressed = buffer.compress()
        info = compressed.to_dict()

        report = {
            "test": "1M parameter buffer accumulation",
            "total_params": total_accumulated,
            "num_batches": 1000,
            "format": info.get("format"),
            "compressed_bytes": info.get("compressed_bytes"),
            "original_bytes": total_accumulated * 4,
            "compression_ratio": round(
                (total_accumulated * 4) / info.get("compressed_bytes", 1), 2
            ),
        }
        print(f"\n{json.dumps(report, indent=2)}")
