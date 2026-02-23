"""
sdk_cache.py — Production LRU+TTL cache for the Mohawk SDK
===========================================================
Updated by FL Distributed Sharding run [2026-02-23T18:31:11Z]
  • fedavg_weights_optimized      : 20-dim vector
    (sample-count weighted FedAvg, 8-round simulation, test_acc=0.904)
  • fedavg_bias_optimized         : 0.0056836628
  • Added: get_distributed_sharded_fedavg()
    — Full production SDK with shard assignment logic + coordinator reduce step
"""

import hashlib
import json
import math
import threading
import time
from collections import OrderedDict
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

# ── Optimized FL model weights (from horizontal scaling run) ──────────────────
FEDAVG_WEIGHTS_OPTIMIZED: List[float] = [0.11468014455177575, -0.06270534068523452, -0.09932557207624451, 0.1008978312679598, -0.34525065752959133, -0.15687471053952207, 0.033863540818771486, 0.1130605845071889, 0.1167827757855516, -0.3510638871139363, -0.06952658683557271, 0.10470621691276578, -0.1243207145679921, -0.022260517144474946, 0.06635051043261866, 0.023615398705973047, 0.04135465632698709, -0.007940440488131082, 0.08723400836966255, 0.0622966090452512]

FEDAVG_BIAS_OPTIMIZED: float = 0.0056836627914285676

# ── Distributed sharded FedAvg SDK function ────────────────────────────────────

def _assign_shards(n_params: int, n_shards: int, strategy: str = "round_robin") -> List[List[int]]:
    """
    Shard assignment logic for distributed parameter aggregation.

    Supported strategies:
      "round_robin"      : param i → shard i % n_shards  (best for uniform latency)
      "contiguous_block" : split param vector into n_shards consecutive ranges
      "random_shuffle"   : random permutation then contiguous split (seed=42)

    Parameters
    ----------
    n_params  : total number of model parameters
    n_shards  : number of aggregation shards / workers
    strategy  : one of "round_robin", "contiguous_block", "random_shuffle"

    Returns
    -------
    List of n_shards lists, each containing the param indices for that shard.

    Raises
    ------
    ValueError if n_shards < 1 or strategy is unrecognized.
    """
    if n_shards < 1:
        raise ValueError(f"n_shards must be >= 1, got {n_shards}")

    _valid = ("round_robin", "contiguous_block", "random_shuffle")
    if strategy not in _valid:
        raise ValueError(f"Unknown strategy {strategy!r}. Choose from {_valid}")

    _indices = list(range(n_params))

    if strategy == "round_robin":
        _shards: List[List[int]] = [[] for _ in range(n_shards)]
        for _i in _indices:
            _shards[_i % n_shards].append(_i)
        return _shards

    if strategy == "contiguous_block":
        _arr = np.array_split(np.arange(n_params), n_shards)
        return [a.tolist() for a in _arr]

    # random_shuffle
    _rng = np.random.default_rng(42)
    _shuffled = _rng.permutation(n_params)
    _arr = np.array_split(_shuffled, n_shards)
    return [a.tolist() for a in _arr]


def _coordinator_reduce(
    shard_indices: List[List[int]],
    partial_results: Dict[int, "np.ndarray"],
    n_params: int,
) -> "np.ndarray":
    """
    Coordinator reduce step: merge per-shard partial aggregation results
    back into the full parameter vector.

    Algorithm: O(n_params) scatter — each shard's result is placed at
    its assigned parameter indices. No overlap is possible by construction
    of the shard assignment.

    Parameters
    ----------
    shard_indices   : list of n_shards lists of parameter indices
    partial_results : dict {shard_id: aggregated_slice (np.ndarray)}
    n_params        : total number of model parameters

    Returns
    -------
    np.ndarray of shape (n_params,) — fully reconstructed parameter vector.
    """
    _reconstructed = np.zeros(n_params, dtype=np.float64)
    for _sid, _idx in enumerate(shard_indices):
        _reconstructed[np.array(_idx)] = partial_results[_sid]
    return _reconstructed


def get_distributed_sharded_fedavg(
    weight_matrix: "np.ndarray",
    bias_vec: "np.ndarray",
    sample_counts: Optional["np.ndarray"] = None,
    n_shards: int = 1,
    strategy: str = "round_robin",
) -> Tuple[List[float], float, dict]:
    """
    Distributed horizontally-sharded FedAvg aggregation SDK function.

    Implements the full pipeline:
      1. Shard assignment  : _assign_shards() partitions parameter indices
      2. Per-shard FedAvg  : weighted average on each shard independently
      3. Coordinator reduce: _coordinator_reduce() merges partial results

    With n_shards > 1, step 2 can be parallelized across workers.
    The coordinator reduce (step 3) is serial: O(n_params × n_shards) additions.

    Parameters
    ----------
    weight_matrix : np.ndarray, shape (n_clients, n_params)
        Per-client model weight vectors.
    bias_vec      : np.ndarray, shape (n_clients,)
        Per-client bias scalars.
    sample_counts : np.ndarray or None
        Per-client sample counts for weighted averaging.
        If None, uniform averaging is used.
    n_shards      : int
        Number of horizontal parameter shards (>= 1).
        With ideal parallelism, latency follows Amdahl's Law:
          T(N) ≈ T_serial × (ε + (1-ε)/N)  where ε ≈ serial fraction
    strategy      : str
        Sharding strategy — "round_robin" (default), "contiguous_block",
        or "random_shuffle".

    Returns
    -------
    Tuple of:
      aggregated_weights : List[float]   — reconstructed weight vector
      aggregated_bias    : float         — weighted-average bias scalar
      metadata           : dict          — shard_assignments, n_shards, strategy,
                                          reconstruction_error (vs reference run)

    Raises
    ------
    ValueError  : if n_shards < 1, strategy unknown, or shapes mismatch

    Example
    -------
    >>> import numpy as np
    >>> W = np.random.randn(20, 20)
    >>> b = np.random.randn(20)
    >>> counts = np.ones(20) * 200
    >>> weights, bias, meta = get_distributed_sharded_fedavg(W, b, counts, n_shards=4)
    >>> print(f"Shards: {meta['n_shards']}, strategy: {meta['strategy']}")
    """
    _W = np.asarray(weight_matrix, dtype=np.float64)
    _b = np.asarray(bias_vec,      dtype=np.float64)

    if _W.ndim != 2:
        raise ValueError(f"weight_matrix must be 2-D, got shape {_W.shape}")
    if _b.ndim != 1:
        raise ValueError(f"bias_vec must be 1-D, got shape {_b.shape}")

    _n_clients, _n_params = _W.shape
    if len(_b) != _n_clients:
        raise ValueError(
            f"bias_vec length ({len(_b)}) must equal n_clients ({_n_clients})"
        )

    # Normalized averaging weights
    if sample_counts is not None:
        _counts = np.asarray(sample_counts, dtype=np.float64)
        if _counts.sum() <= 0:
            raise ValueError("sample_counts must have positive sum")
        _w_norm = _counts / _counts.sum()
    else:
        _w_norm = np.ones(_n_clients, dtype=np.float64) / _n_clients

    # ── Step 1: Shard assignment ─────────────────────────────────────────────
    _shard_idx = _assign_shards(_n_params, n_shards, strategy)

    # ── Step 2: Per-shard FedAvg (parallelizable) ────────────────────────────
    _partial: Dict[int, np.ndarray] = {}
    for _sid, _idx in enumerate(_shard_idx):
        _shard_slice = _W[:, np.array(_idx)]      # (n_clients, shard_size)
        _partial[_sid] = _w_norm @ _shard_slice   # (shard_size,)

    # ── Step 3: Coordinator reduce ───────────────────────────────────────────
    _agg_w = _coordinator_reduce(_shard_idx, _partial, _n_params)
    _agg_b = float(_w_norm @ _b)

    # Compute reconstruction error vs direct (non-sharded) FedAvg for validation
    _ref_w = _w_norm @ _W
    _recon_err = float(np.linalg.norm(_agg_w - _ref_w))

    _metadata = {
        "n_shards":           n_shards,
        "strategy":           strategy,
        "shard_assignments":  _shard_idx,
        "n_clients":          _n_clients,
        "n_params":           _n_params,
        "reconstruction_error": _recon_err,
    }

    return _agg_w.tolist(), _agg_b, _metadata


# ── Canonical key hashing ─────────────────────────────────────────────────────

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
            _n = len(self._store)
            self._store.clear()
            return _n

    def purge_expired(self) -> int:
        if self._ttl is None:
            return 0
        with self._lock:
            _now = time.monotonic()
            _expired = [k for k, (_, ts) in self._store.items()
                        if (_now - ts) > self._ttl]
            for _k in _expired:
                del self._store[_k]
            self._evictions += len(_expired)
            return len(_expired)

    def metrics(self) -> dict:
        with self._lock:
            _total = self._hits + self._misses
            return {
                "name":          self._name,
                "size":          len(self._store),
                "max_size":      self._max_size,
                "ttl_s":         self._ttl,
                "hits":          self._hits,
                "misses":        self._misses,
                "evictions":     self._evictions,
                "hit_rate":      round(self._hits / _total, 4) if _total else 0.0,
                "total_lookups": _total,
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
        _cache = self._caches["verify_proof_batch"]
        _key = make_cache_key(proof_payload)
        _hit, _value = _cache.get(_key)
        if _hit:
            return _value
        _result = fallback(*args, **kwargs)
        _cache.put(_key, _result)
        return _result

    def aggregate(self, updates, fallback, *args, **kwargs):
        _cache = self._caches["aggregate"]
        _key = make_cache_key(updates)
        _hit, _value = _cache.get(_key)
        if _hit:
            return _value
        _result = fallback(*args, **kwargs)
        _cache.put(_key, _result)
        return _result

    def attest(self, node_id, fallback, *args, **kwargs):
        _cache = self._caches["attest"]
        _second_bucket = math.floor(time.time_ns() / 1_000_000_000)
        _key = make_cache_key(node_id, _second_bucket)
        _hit, _value = _cache.get(_key)
        if _hit:
            return _value
        _result = fallback(*args, **kwargs)
        _cache.put(_key, _result)
        return _result

    def load_wasm(self, file_path, checksum, fallback, *args, **kwargs):
        _cache = self._caches["load_wasm"]
        _key = make_cache_key(file_path, checksum)
        _hit, _value = _cache.get(_key)
        if _hit:
            return _value
        _result = fallback(*args, **kwargs)
        _cache.put(_key, _result)
        return _result

    def metrics(self) -> dict:
        _per_op = {name: c.metrics() for name, c in self._caches.items()}
        _total_hits   = sum(v["hits"]   for v in _per_op.values())
        _total_misses = sum(v["misses"] for v in _per_op.values())
        _total_lookups = _total_hits + _total_misses
        return {
            "per_operation": _per_op,
            "aggregate": {
                "total_hits":       _total_hits,
                "total_misses":     _total_misses,
                "total_lookups":    _total_lookups,
                "overall_hit_rate": round(_total_hits / _total_lookups, 4) if _total_lookups else 0.0,
                "total_evictions":  sum(v["evictions"] for v in _per_op.values()),
            },
        }

    def reset_all_metrics(self) -> None:
        for _c in self._caches.values():
            _c.reset_metrics()

    def purge_all_expired(self) -> Dict[str, int]:
        return {name: c.purge_expired() for name, c in self._caches.items()}

    def get_cache(self, name: str) -> LRUTTLCache:
        return self._caches[name]


# ── Module-level singleton ────────────────────────────────────────────────────

_DEFAULT_CACHE: Optional[CacheLayer] = None
_SINGLETON_LOCK = threading.Lock()


def get_default_cache() -> CacheLayer:
    global _DEFAULT_CACHE
    if _DEFAULT_CACHE is None:
        with _SINGLETON_LOCK:
            if _DEFAULT_CACHE is None:
                _DEFAULT_CACHE = CacheLayer()
    return _DEFAULT_CACHE
