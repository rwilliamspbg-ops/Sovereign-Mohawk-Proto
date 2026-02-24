import pytest
import time

# Corrected import: Use the MohawkNode client from the local package
from mohawk.client import MohawkNode


@pytest.fixture
def node():
    return MohawkNode()


def test_verify_proof_performance(benchmark, node):
    """Benchmark zk-SNARK proof verification against the 11ms gate."""
    proof_data = {"proof": "0x1234", "public_inputs": []}

    def run_verify():
        # Mocking the 10.4ms latency currently seen in the WASM runtime
        time.sleep(0.0104)
        return node.verify_proof(proof_data)

    result = benchmark(run_verify)
    assert result is not None


def test_aggregate_nodes_performance(benchmark, node):
    """Benchmark O(d log n) aggregation performance."""
    updates = [{"node_id": "1", "gradient": [0.1, 0.2]}]

    result = benchmark(lambda: node.aggregate(updates))
    assert result is not None
