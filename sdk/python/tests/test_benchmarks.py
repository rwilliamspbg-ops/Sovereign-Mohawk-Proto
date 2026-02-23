import pytest
import numpy as np
from sdk_cache import get_default_cache, get_distributed_sharded_fedavg

@pytest.fixture
def cache():
    return get_default_cache()

def test_verify_proof_batch_benchmark(benchmark, cache):
    """Benchmarks zk-SNARK proof verification caching."""
    payload = {"proof": "0xabc123", "root": "0x987654"}
    def mock_verify(): return True
    
    # This matches the 'verify_proof_batch' key in your YAML gate
    benchmark(cache.verify_proof_batch, payload, mock_verify)

def test_aggregate_nodes_benchmark(benchmark):
    """Benchmarks sharded FedAvg aggregation."""
    weights = np.random.rand(10, 1000)
    bias = np.random.rand(10)
    
    # This matches the 'aggregate_nodes' key in your YAML gate
    benchmark(get_distributed_sharded_fedavg, weights, bias, n_shards=4)

def test_attest_benchmark(benchmark, cache):
    """Benchmarks node attestation performance."""
    node_id = "node_001"
    def mock_attest(): return "signed_state_0x123"
    
    # This matches the 'attest' key in your YAML gate
    benchmark(cache.attest, node_id, mock_attest)
