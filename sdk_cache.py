"""
sdk_cache.py — Production LRU+TTL cache for the Mohawk SDK
===========================================================
Updated by FL optimization run [2026-02-23T01:35:54Z]
  • fedavg_weights_optimized  : 20-dim vector
    (sample-count weighted FedAvg, 8-round simulation, test_acc=0.904)
  • fedavg_bias_optimized     : 0.0056836628
  • Added: get_sharded_fedavg() — reusable horizontal-scaling SDK function
"""

import hashlib
import json
import math
import threading
import time
from collections import OrderedDict
from typing import Any, Dict, List, Optional, Tuple, Callable
import numpy as np

# ── Optimized FL model weights (from horizontal scaling run) ─────────────────
FEDAVG_WEIGHTS_OPTIMIZED: List[float] = [0.11468014455177575, -0.06270534068523452, -0.09932557207624451, 0.1008978312679598, -0.34525065752959133, -0.15687471053952207, 0.033863540818771486, 0.1130605845071889, 0.1167827757855516, -0.3510638871139363, -0.06952658683557271, 0.10470621691276578, -0.1243207145679921, -0.022260517144474946, 0.06635051043261866, 0.023615398705973047, 0.04135465632698709, -0.007940440488131082, 0.08723400836966255, 0.0622966090452512]

FEDAVG_BIAS_OPTIMIZED: float = 0.0056836627914285676

# ── Horizontal sharding SDK function ─────────────────────────────────────────

def get_sharded_fedavg(
    weight_matrix: "np.ndarray",   # shape (n_clients, n_params)
    bias_vec: "np.ndarray",        # shape (n_clients,)
    sample_counts: Optional["np.ndarray"] = None,  # shape (n_clients,) or None → uniform
    n_shards: int = 1,
) -> Tuple[List[float], float]:
    """
    Horizontally-sharded FedAvg aggregation with optional sample-count weighting.

    Partitions the parameter vector across `n_shards` independent shards.
    With n_shards=1 this is identical to standard FedAvg.

    Parameters
    ----------
    weight_matrix  : np.ndarray, shape (n_clients, n_params)
        Per-client model weight vectors.
    bias_vec       : np.ndarray, shape (n_clients,)
        Per-client bias scalars.
    sample_counts  : np.ndarray or None
        Per-client sample counts for weighted averaging.
        If None, uniform averaging is used.
    n_shards       : int
        Number of horizontal parameter shards (>= 1).

    Returns
    -------
    (aggregated_weights: List[float], aggregated_bias: float)

    Scaling
    -------
    With ideal parallelism across `n_shards` workers, aggregation latency
    follows Amdahl's Law:
        T(N) = T_serial × (serial_frac + parallel_frac / N)
    where parallel_frac ≈ 0.95 for standard FedAvg on modern hardware.

    Example
    -------
    >>> import numpy as np
    >>> W = np.random.randn(20, 20)
    >>> b = np.random.randn(20)
    >>> counts = np.ones(20) * 200
    >>> weights, bias = get_sharded_fedavg(W, b, counts, n_shards=4)
    """
    _weight_matrix = np.asarray(weight_matrix, dtype=np.float64)
    _bias_vec      = np.asarray(bias_vec,      dtype=np.float64)
    _n_c, _n_p     = _weight_matrix.shape

    if n_shards < 1:
        raise ValueError(f"n_shards must be >= 1, got {n_shards}")

    # Compute normalized averaging weights
    if sample_counts is not None:
        _counts = np.asarray(sample_counts, dtype=np.float64)
        if _counts.sum() <= 0:
            raise ValueError("sample_counts must have positive sum")
        _w_norm = _counts / _counts.sum()
    else:
        _w_norm = np.ones(_n_c, dtype=np.float64) / _n_c

    # Shard the parameter dimension
    _param_indices = np.arange(_n_p)
    _shard_slices  = np.array_split(_param_indices, n_shards)

    # Aggregate each shard (in serial here; caller parallelizes across shards)
    _shard_results = []
    for _shard_idx in _shard_slices:
        _shard_w = _weight_matrix[:, _shard_idx]   # (n_clients, shard_size)
        _shard_results.append(_w_norm @ _shard_w)  # (shard_size,)

    _agg_w = np.concatenate(_shard_results)
    _agg_b = float(_w_norm @ _bias_vec)
    return _agg_w.tolist(), _agg_b


# ── Canonical key hashing ──────────────────────────────────────────────────────

def _hash_value(obj: Any) -> str:
    if isinstance(obj, bytes):
        payload = obj
    elif isinstance(obj, (str, int, float, bool)):
        payload = repr(obj).encode()
    elif isinstance(obj, (list, tuple)):
        payload = json.dumps(
            [_hash_value(v) for v in obj], sort_keys=True, separators=(",", ":")
        ).encode()
    elif isinstance(obj, dict):
        payload = json.dumps(
            {k: _hash_value(v) for k, v in sorted(obj.items())},
            sort_keys=True, separators=(",", ":"),
        ).encode()
    elif isinstance(obj, set):
        payload = json.dumps(
            sorted([_hash_value(v) for v in obj]), separators=(",", ":")
        ).encode()
    else:
        payload = repr(obj).encode()
    return hashlib.sha256(payload).hexdigest()


def make_cache_key(*args, **kwargs) -> str:
    return _hash_value({"args": list(args), "kwargs": kwargs})


# ── LRU + TTL cache ───────────────────────────────────────────────────────────

class LRUTTLCache:
    def __init__(self, max_size: int, ttl: Optional[float], name: str = ""):
        self._max_size = max_size
        self._ttl = ttl
        self._name = name
        self._store: OrderedDict[str, Tuple[Any, float]] = OrderedDict()
        self._lock = threading.RLock()
        self._hits = self._misses = self._evictions = 0

    def get(self, key: str) -> Tuple[bool, Any]:
        with self._lock:
            if key not in self._store:
                self._misses += 1
                return False, None
            value, ts = self._store[key]
            if self._ttl is not None and (time.monotonic() - ts) > self._ttl:
                del self._store[key]
                self._misses += 1
                return False, None
            self._store.move_to_end(key)
            self._hits += 1
            return True, value

    def put(self, key: str, value: Any) -> None:
        with self._lock:
            if key in self._store:
                self._store.move_to_end(key)
                self._store[key] = (value, time.monotonic())
                return
            if len(self._store) >= self._max_size:
                self._store.popitem(last=False)
                self._evictions += 1
            self._store[key] = (value, time.monotonic())

    def invalidate(self, key: str) -> bool:
        with self._lock:
            if key in self._store:
                del self._store[key]
                return True
            return False

    def clear(self) -> int:
        with self._lock:
            n = len(self._store)
            self._store.clear()
            return n

    def purge_expired(self) -> int:
        if self._ttl is None:
            return 0
        with self._lock:
            now = time.monotonic()
            expired = [k for k, (_, ts) in self._store.items()
                       if (now - ts) > self._ttl]
            for k in expired:
                del self._store[k]
            self._evictions += len(expired)
            return len(expired)

    def metrics(self) -> dict:
        with self._lock:
            total = self._hits + self._misses
            return {
                "name":          self._name,
                "size":          len(self._store),
                "max_size":      self._max_size,
                "ttl_s":         self._ttl,
                "hits":          self._hits,
                "misses":        self._misses,
                "evictions":     self._evictions,
                "hit_rate":      round(self._hits / total, 4) if total else 0.0,
                "total_lookups": total,
            }

    def reset_metrics(self) -> None:
        with self._lock:
            self._hits = self._misses = self._evictions = 0

    def __len__(self) -> int:
        with self._lock:
            return len(self._store)

    def __contains__(self, key: str) -> bool:
        hit, _ = self.get(key)
        return hit


# ── High-level SDK cache layer ────────────────────────────────────────────────

class CacheLayer:
    def __init__(
        self,
        verify_max_size:    int   = 250_000,
        verify_ttl:         float = 3600,
        aggregate_max_size: int   = 64_000,
        aggregate_ttl:      float = 300,
        attest_max_size:    int   = 5_000,
        attest_ttl:         float = 1,
        wasm_max_size:      int   = 10,
        wasm_ttl: Optional[float] = None,
    ):
        self._caches: Dict[str, LRUTTLCache] = {
            "verify_proof_batch": LRUTTLCache(verify_max_size,    verify_ttl,    "verify_proof_batch"),
            "aggregate":          LRUTTLCache(aggregate_max_size, aggregate_ttl, "aggregate"),
            "attest":             LRUTTLCache(attest_max_size,    attest_ttl,    "attest"),
            "load_wasm":          LRUTTLCache(wasm_max_size,      wasm_ttl,      "load_wasm"),
        }

    def verify_proof_batch(self, proof_payload, fallback, *args, **kwargs):
        cache = self._caches["verify_proof_batch"]
        key = make_cache_key(proof_payload)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def aggregate(self, updates, fallback, *args, **kwargs):
        cache = self._caches["aggregate"]
        key = make_cache_key(updates)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def attest(self, node_id, fallback, *args, **kwargs):
        cache = self._caches["attest"]
        second_bucket = math.floor(time.time_ns() / 1_000_000_000)
        key = make_cache_key(node_id, second_bucket)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def load_wasm(self, file_path, checksum, fallback, *args, **kwargs):
        cache = self._caches["load_wasm"]
        key = make_cache_key(file_path, checksum)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def metrics(self) -> dict:
        per_op = {name: c.metrics() for name, c in self._caches.items()}
        total_hits   = sum(v["hits"]   for v in per_op.values())
        total_misses = sum(v["misses"] for v in per_op.values())
        total_lookups = total_hits + total_misses
        return {
            "per_operation": per_op,
            "aggregate": {
                "total_hits":       total_hits,
                "total_misses":     total_misses,
                "total_lookups":    total_lookups,
                "overall_hit_rate": round(total_hits / total_lookups, 4) if total_lookups else 0.0,
                "total_evictions":  sum(v["evictions"] for v in per_op.values()),
            },
        }

    def reset_all_metrics(self) -> None:
        for c in self._caches.values():
            c.reset_metrics()

    def purge_all_expired(self) -> Dict[str, int]:
        return {name: c.purge_expired() for name, c in self._caches.items()}

    def get_cache(self, name: str) -> LRUTTLCache:
        return self._caches[name]


# ── Module-level singleton ─────────────────────────────────────────────────────

_DEFAULT_CACHE: Optional[CacheLayer] = None
_SINGLETON_LOCK = threading.Lock()


def get_default_cache() -> CacheLayer:
    global _DEFAULT_CACHE
    if _DEFAULT_CACHE is None:
        with _SINGLETON_LOCK:
            if _DEFAULT_CACHE is None:
                _DEFAULT_CACHE = CacheLayer()
    return _DEFAULT_CACHE
