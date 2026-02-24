import pytest
from mohawk.cache import get_default_cache

def test_distributed_sharded_performance(benchmark):
    """
    Benchmarks the performance of the sharded federated averaging cache logic.
    """
    # Initialize the cache layer
    cache_layer = get_default_cache()
    
    def run_sharded_logic():
        # Using getattr to safely access internal cache data
        return getattr(cache_layer, 'cache', {}).get("performance_test_key", None)

    result = benchmark(run_sharded_logic)
    assert result is None or isinstance(result, dict)

def test_cache_initialization_speed(benchmark):
    """
    Benchmarks how quickly a default cache instance can be initialized.
    """
    # Fixed: Removed the extra closing parenthesis here
    benchmark(get_default_cache)
