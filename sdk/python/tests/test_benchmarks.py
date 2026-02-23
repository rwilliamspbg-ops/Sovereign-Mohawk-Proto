import pytest
import numpy as np
from sdk_cache import get_default_cache, get_distributed_sharded_fedavg

@pytest.fixture
def cache():
    return get_default_cache()

def test_verify_proof_batch_benchmark(benchmark, cache):
    """Benchmarks zk-SNARK proof verification (Target: p99 < 6.0ms)."""
    payload = {"proof": "0xabc123", "root": "0x987654"}
    benchmark(cache.verify_proof_batch, payload, lambda: True)

def test_aggregate_nodes_benchmark(benchmark):
    """Benchmarks sharded FedAvg (Target: mean < 25.0ms)."""
    weights = np.random.rand(10, 1000)
    bias = np.random.rand(10)
    benchmark(get_distributed_sharded_fedavg, weights, bias, n_shards=4)

def test_attest_benchmark(benchmark, cache):
    """Benchmarks node attestation (Target: > 4000 ops/s)."""
    benchmark(cache.attest, "node_001", lambda: "signed_state")
