"""
sdk_cache.py — Production LRU+TTL cache for the Mohawk SDK
===========================================================
Updated by FL fault tolerance run [2026-02-23T19:51:11Z]
  • fedavg_weights_optimized   : 20-dim vector
    (sample-count weighted FedAvg, 8-round simulation, test_acc=0.904)
  • fedavg_bias_optimized      : 0.0056836628
  • Added: get_sharded_fedavg()         — horizontal-scaling aggregation
  • Added: get_fault_tolerant_fedavg()  — fault-tolerant wrapper with
    dropout_mask, recovery_strategy, re-sharding, fallback, partial agg
"""

import hashlib
import json
import math
import threading
import time
from collections import OrderedDict
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

# ── Optimized FL model weights (from horizontal scaling run) ─────────────────
FEDAVG_WEIGHTS_OPTIMIZED: List[float] = [0.11468014455177575, -0.06270534068523452, -0.09932557207624451, 0.1008978312679598, -0.34525065752959133, -0.15687471053952207, 0.033863540818771486, 0.1130605845071889, 0.1167827757855516, -0.3510638871139363, -0.06952658683557271, 0.10470621691276578, -0.1243207145679921, -0.022260517144474946, 0.06635051043261866, 0.023615398705973047, 0.04135465632698709, -0.007940440488131082, 0.08723400836966255, 0.0622966090452512]

FEDAVG_BIAS_OPTIMIZED: float = 0.0056836627914285676

# ── Horizontal sharding SDK function ─────────────────────────────────────────

def get_sharded_fedavg(
    weight_matrix: "np.ndarray",   # shape (n_clients, n_params)
    bias_vec: "np.ndarray",        # shape (n_clients,)
    sample_counts: Optional["np.ndarray"] = None,
    n_shards: int = 1,
) -> Tuple[List[float], float]:
    """
    Horizontally-sharded FedAvg aggregation with optional sample-count weighting.

    Partitions the parameter vector across `n_shards` independent shards.
    With n_shards=1 this is identical to standard FedAvg.

    Parameters
    ----------
    weight_matrix  : np.ndarray, shape (n_clients, n_params)
    bias_vec       : np.ndarray, shape (n_clients,)
    sample_counts  : np.ndarray or None  (uniform if None)
    n_shards       : int  (>= 1)

    Returns
    -------
    (aggregated_weights: List[float], aggregated_bias: float)

    Example
    -------
    >>> import numpy as np
    >>> W = np.random.randn(20, 20)
    >>> b = np.random.randn(20)
    >>> counts = np.ones(20) * 200
    >>> weights, bias = get_sharded_fedavg(W, b, counts, n_shards=4)
    """
    _wm = np.asarray(weight_matrix, dtype=np.float64)
    _bv = np.asarray(bias_vec,      dtype=np.float64)
    _nc, _np = _wm.shape
    if n_shards < 1:
        raise ValueError(f"n_shards must be >= 1, got {n_shards}")
    if sample_counts is not None:
        _sc = np.asarray(sample_counts, dtype=np.float64)
        if _sc.sum() <= 0:
            raise ValueError("sample_counts must have positive sum")
        _wn = _sc / _sc.sum()
    else:
        _wn = np.ones(_nc, dtype=np.float64) / _nc
    _shards = np.array_split(np.arange(_np), n_shards)
    _parts  = [_wn @ _wm[:, _s] for _s in _shards]
    return np.concatenate(_parts).tolist(), float(_wn @ _bv)


# ── Fault-tolerant FedAvg wrapper ─────────────────────────────────────────────

def get_fault_tolerant_fedavg(
    weight_matrix: "np.ndarray",           # shape (n_clients, n_params)
    bias_vec: "np.ndarray",                # shape (n_clients,)
    sample_counts: Optional["np.ndarray"] = None,
    n_shards: int = 4,
    dropout_mask: Optional[List[int]] = None,
    recovery_strategy: str = "re_sharding",
    prev_shard_results: Optional[Dict[int, "np.ndarray"]] = None,
    ref_param_vec: Optional["np.ndarray"] = None,
) -> Tuple[List[float], float, Dict[str, Any]]:
    """
    Fault-tolerant wrapper around get_distributed_sharded_fedavg() that accepts
    a dropout_mask and recovery_strategy argument and automatically handles
    re-sharding, fallback, and partial aggregation.

    Parameters
    ----------
    weight_matrix       : np.ndarray, shape (n_clients, n_params)
        Per-client model weight vectors.
    bias_vec            : np.ndarray, shape (n_clients,)
        Per-client bias scalars.
    sample_counts       : np.ndarray or None
        Per-client sample counts for weighted averaging (uniform if None).
    n_shards            : int
        Number of horizontal parameter shards (>= 1).
    dropout_mask        : List[int] or None
        Indices (0-based) of failed/dropped shards. An empty list or None
        means no failures — equivalent to a clean get_sharded_fedavg() call.
    recovery_strategy   : str
        One of:
          "re_sharding"        — redistribute failed shard(s) round-robin
                                  across surviving shards.
          "last_known_good"    — substitute each failed shard with the result
                                  from prev_shard_results (cache fallback).
          "partial_aggregation"— skip failed shards entirely; fill failed
                                  parameter positions from ref_param_vec (or
                                  zeros if ref_param_vec is None).
    prev_shard_results  : Dict[int, np.ndarray] or None
        Previous-round shard output vectors keyed by shard index.
        Required for "last_known_good" strategy.
    ref_param_vec       : np.ndarray or None
        Reference / last-known-global parameter vector used to fill failed
        shard positions in "partial_aggregation" mode.

    Returns
    -------
    (aggregated_weights : List[float],
     aggregated_bias    : float,
     recovery_meta      : Dict[str, Any])
        recovery_meta includes: strategy_used, failed_shards, surviving_shards,
        recovery_overhead_ms (model estimate), fault_signal (bool).

    Raises
    ------
    ValueError
        If recovery_strategy is unrecognised or all shards have failed with a
        strategy that cannot proceed.
    RuntimeError
        If dropout_mask covers ALL shards (complete failure) — raises a clean
        fault signal instead of silently returning a corrupt model.

    Example
    -------
    >>> import numpy as np
    >>> W = np.random.randn(20, 20)
    >>> b = np.random.randn(20)
    >>> counts = np.ones(20) * 200
    >>> # Simulate shard-1 failing, use re-sharding recovery
    >>> weights, bias, meta = get_fault_tolerant_fedavg(
    ...     W, b, counts,
    ...     n_shards=4,
    ...     dropout_mask=[1],
    ...     recovery_strategy="re_sharding",
    ... )
    >>> print(meta["strategy_used"], meta["fault_signal"])
    re_sharding False
    """
    _wm = np.asarray(weight_matrix, dtype=np.float64)
    _bv = np.asarray(bias_vec,      dtype=np.float64)
    _nc, _np = _wm.shape

    if n_shards < 1:
        raise ValueError(f"n_shards must be >= 1, got {n_shards}")
    if recovery_strategy not in ("re_sharding", "last_known_good", "partial_aggregation"):
        raise ValueError(
            f"recovery_strategy must be one of 're_sharding', 'last_known_good', "
            f"'partial_aggregation'; got {recovery_strategy!r}"
        )

    # Normalised sample weights
    if sample_counts is not None:
        _sc = np.asarray(sample_counts, dtype=np.float64)
        if _sc.sum() <= 0:
            raise ValueError("sample_counts must have positive sum")
        _wn = _sc / _sc.sum()
    else:
        _wn = np.ones(_nc, dtype=np.float64) / _nc

    # Build shard index lists (round-robin style)
    _all_param_idx = np.arange(_np)
    _shard_slices  = [arr.tolist() for arr in np.array_split(_all_param_idx, n_shards)]

    # Normalise dropout_mask
    _failed  = sorted(set(dropout_mask)) if dropout_mask else []
    _survive = [s for s in range(n_shards) if s not in _failed]

    # ── Complete failure: raise clean fault signal ─────────────────────────
    if len(_failed) >= n_shards:
        raise RuntimeError(
            f"FAULT_SIGNAL: All {n_shards} shards failed (dropout_mask={_failed}). "
            "Distributed FedAvg cannot proceed. Returning clean exception to caller — "
            "no silent model corruption. Action: fall back to last committed global model."
        )

    _t_start = time.monotonic()

    # ── No failures: fast path ────────────────────────────────────────────
    if not _failed:
        _parts = [_wn @ _wm[:, np.array(_shard_slices[s])] for s in range(n_shards)]
        _agg_w = np.concatenate(_parts)
        _agg_b = float(_wn @ _bv)
        _elapsed = (time.monotonic() - _t_start) * 1000.0
        _meta = dict(
            strategy_used="none",
            failed_shards=[],
            surviving_shards=list(range(n_shards)),
            recovery_overhead_ms=_elapsed,
            fault_signal=False,
        )
        return _agg_w.tolist(), _agg_b, _meta

    # ── RE-SHARDING ────────────────────────────────────────────────────────
    if recovery_strategy == "re_sharding":
        # Build new shard mapping: redistribute failed shard params round-robin
        _new_shards: Dict[int, List[int]] = {s: list(_shard_slices[s]) for s in _survive}
        for _fs in _failed:
            for _pi, _p in enumerate(_shard_slices[_fs]):
                _target = _survive[_pi % len(_survive)]
                _new_shards[_target].append(_p)
        # Aggregate over new shards
        _recon = np.zeros(_np, dtype=np.float64)
        for _sid, _idx in _new_shards.items():
            _sidx = sorted(_idx)
            _recon[np.array(_sidx)] = _wn @ _wm[:, np.array(_sidx)]
        _agg_w = _recon
        _agg_b = float(_wn @ _bv)
        # Latency model: one extra RTT (50 ms default) + proportional recompute
        _RTT_MS = 50.0
        _overhead = _RTT_MS + ((_np * len(_failed) / n_shards) / len(_survive)) * 0.001

    # ── LAST-KNOWN-GOOD ────────────────────────────────────────────────────
    elif recovery_strategy == "last_known_good":
        # Compute surviving shard results
        _partial: Dict[int, "np.ndarray"] = {}
        for _s in _survive:
            _idx = np.array(_shard_slices[_s])
            _partial[_s] = _wn @ _wm[:, _idx]
        # Fill failed shards from prev_shard_results cache (or zeros)
        for _fs in _failed:
            _idx = np.array(_shard_slices[_fs])
            if prev_shard_results is not None and _fs in prev_shard_results:
                _partial[_fs] = np.asarray(prev_shard_results[_fs], dtype=np.float64)
            else:
                _partial[_fs] = np.zeros(len(_shard_slices[_fs]), dtype=np.float64)
        # Reconstruct
        _recon = np.zeros(_np, dtype=np.float64)
        for _s, _idx_list in enumerate(_shard_slices):
            _recon[np.array(_idx_list)] = _partial[_s]
        _agg_w = _recon
        _agg_b = float(_wn @ _bv)
        # Latency model: 0.5 RTT per failed shard (cache read)
        _overhead = 25.0 * len(_failed)

    # ── PARTIAL AGGREGATION ───────────────────────────────────────────────
    else:  # partial_aggregation
        _recon = np.zeros(_np, dtype=np.float64)
        # Fill surviving shards
        for _s in _survive:
            _idx = np.array(_shard_slices[_s])
            _recon[_idx] = _wn @ _wm[:, _idx]
        # Fill failed shard positions with ref_param_vec (or zeros)
        for _fs in _failed:
            _idx = np.array(_shard_slices[_fs])
            if ref_param_vec is not None:
                _ref = np.asarray(ref_param_vec, dtype=np.float64)
                _recon[_idx] = _ref[_idx]
            # else: leave as zeros (already zero-initialised)
        _agg_w = _recon
        _agg_b = float(_wn @ _bv)
        # Latency model: ~0.5 ms per dropped shard for renormalisation
        _overhead = 0.5 * len(_failed)

    _elapsed = (time.monotonic() - _t_start) * 1000.0
    _meta = dict(
        strategy_used=recovery_strategy,
        failed_shards=_failed,
        surviving_shards=_survive,
        recovery_overhead_ms=_overhead,
        fault_signal=False,
    )
    return _agg_w.tolist(), _agg_b, _meta


# ── Convenience alias: get_distributed_sharded_fedavg ─────────────────────────
# Provides the same interface as get_sharded_fedavg but is the canonical
# name used for the distributed, multi-server implementation.

def get_distributed_sharded_fedavg(
    weight_matrix: "np.ndarray",
    bias_vec: "np.ndarray",
    sample_counts: Optional["np.ndarray"] = None,
    n_shards: int = 1,
) -> Tuple[List[float], float]:
    """
    Distributed, horizontally-sharded FedAvg aggregation.
    Canonical production name for get_sharded_fedavg() — identical behaviour.
    Use get_fault_tolerant_fedavg() for fault-tolerant execution.
    """
    return get_sharded_fedavg(weight_matrix, bias_vec, sample_counts, n_shards)


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
        import time as _time
        second_bucket = math.floor(_time.time_ns() / 1_000_000_000)
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
