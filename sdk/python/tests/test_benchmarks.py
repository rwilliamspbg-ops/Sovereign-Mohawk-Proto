import pytest

from mohawk.exceptions import VerificationError

# Corrected import: Use the MohawkNode client from the local package
from mohawk.client import MohawkNode


@pytest.fixture
def node(monkeypatch):
    monkeypatch.setenv("MOHAWK_DP_SIGMA", "5")
    node = MohawkNode()
    node.bridge.close()
    return node


@pytest.mark.skip(
    reason="RETRACTED: the 10.55 ms figure this test produced was a hardcoded "
    "time.sleep(0.0104), not a measurement of verification. The real zk "
    "verification path is measured in Go: results/zk/weight-proof-latest.json "
    "(verify 0.675 ms, prove 38 ms) via `go run ./cmd/zkweightbench`. "
    "See docs/ZK_FINALIZATION_PLAN.md section 0.2."
)
def test_verify_proof_performance(benchmark, node):
    """Skipped: the former 11 ms gate was measuring a sleep, not verification."""
    proof_data = {"proof": "0x" + "ab" * 128, "public_inputs": []}

    def run_verify():
        try:
            return node.verify_proof(proof_data)
        except VerificationError as exc:
            return {"success": False, "error": str(exc)}

    result = benchmark(run_verify)
    assert result is not None


def test_aggregate_nodes_performance(benchmark, node):
    """Benchmark O(d log n) aggregation performance."""
    updates = [{"node_id": "1", "gradient": [0.1, 0.2]}]

    result = benchmark.pedantic(lambda: node.aggregate(updates), rounds=1, iterations=1)
    assert result is not None


def test_gradient_compression_performance(benchmark, node):
    """Benchmark FP16 gradient compression for SDK transport path."""
    gradients = [0.01 * i for i in range(2048)]

    result = benchmark(lambda: node.compress_gradients(gradients, format="fp16"))
    assert result is not None


def test_gradient_compression_zero_copy_performance(benchmark, node):
    """Benchmark zero-copy FP16 gradient compression for SDK transport path."""
    gradients = bytearray(2048 * 4)
    view = memoryview(gradients).cast("f")
    for i in range(len(view)):
        view[i] = 0.01 * i

    result = benchmark(lambda: node.compress_gradients_zero_copy(view, format="fp16"))
    assert result is not None
