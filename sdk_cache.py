"""
sdk_cache.py — Production-ready LRU+TTL cache for the Mohawk SDK
=================================================================
Thread-safe implementation with:
• SHA-256 content-addressing for complex inputs
• Per-operation configurable max_size and TTL
• Hit / miss / eviction counter metrics
"""

import hashlib
import json
import math
import threading
import time
from collections import OrderedDict
from typing import Any, Callable, Dict, Optional, Tuple


# ── Canonical key hashing ─────────────────────────────────────────────────────


def _hash_value(obj: Any) -> str:
    """Deterministic SHA-256 fingerprint for any hashable value."""
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
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    elif isinstance(obj, set):
        payload = json.dumps(
            sorted([_hash_value(v) for v in obj]), separators=(",", ":")
        ).encode()
    else:
        payload = repr(obj).encode()
    return hashlib.sha256(payload).hexdigest()


def make_cache_key(*args, **kwargs) -> str:
    """Build a cache key from arbitrary positional and keyword arguments."""
    return _hash_value({"args": list(args), "kwargs": kwargs})


# ── Core LRU + TTL cache ──────────────────────────────────────────────────────


class LRUTTLCache:
    """Thread-safe Least-Recently-Used cache with per-entry TTL."""

    def __init__(self, max_size: int, ttl: Optional[float], name: str = ""):
        self._max_size = max_size
        self._ttl = ttl
        self._name = name
        self._store: OrderedDict[str, Tuple[Any, float]] = OrderedDict()
        self._lock = threading.RLock()
        self._hits = 0
        self._misses = 0
        self._evictions = 0

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
            expired = [k for k, (_, ts) in self._store.items() if (now - ts) > self._ttl]
            for k in expired:
                del self._store[k]
            self._evictions += len(expired)
            return len(expired)

    def metrics(self) -> dict:
        with self._lock:
            total = self._hits + self._misses
            return {
                "name": self._name,
                "size": len(self._store),
                "hits": self._hits,
                "misses": self._misses,
                "hit_rate": round(self._hits / total, 4) if total > 0 else 0.0,
            }

    def reset_metrics(self) -> None:
        with self._lock:
            self._hits = self._misses = self._evictions = 0


# ── High-level SDK cache layer ────────────────────────────────────────────────


class CacheLayer:
    """Facade providing caches tailored to each Mohawk SDK operation."""

    def __init__(
        self,
        verify_max_size: int = 250000,
        verify_ttl: float = 3600,
        aggregate_max_size: int = 64000,
        aggregate_ttl: float = 300,
        attest_max_size: int = 5000,
        attest_ttl: float = 1,
        wasm_max_size: int = 10,
        wasm_ttl: Optional[float] = None,
    ):
        self._caches: Dict[str, LRUTTLCache] = {
            "verify_proof_batch": LRUTTLCache(
                verify_max_size, verify_ttl, "verify_proof_batch"
            ),
            "aggregate": LRUTTLCache(aggregate_max_size, aggregate_ttl, "aggregate"),
            "attest": LRUTTLCache(attest_max_size, attest_ttl, "attest"),
            "load_wasm": LRUTTLCache(wasm_max_size, wasm_ttl, "load_wasm"),
        }

    def verify_proof_batch(
        self, proof_payload: dict, fallback: Callable, *args, **kwargs
    ) -> Any:
        cache = self._caches["verify_proof_batch"]
        key = make_cache_key(proof_payload)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def aggregate(self, updates: list, fallback: Callable, *args, **kwargs) -> Any:
        cache = self._caches["aggregate"]
        key = make_cache_key(updates)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def attest(self, node_id: str, fallback: Callable, *args, **kwargs) -> Any:
        cache = self._caches["attest"]
        second_bucket = math.floor(time.time_ns() / 1_000_000_000)
        key = make_cache_key(node_id, second_bucket)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def load_wasm(
        self, file_path: str, checksum: str, fallback: Callable, *args, **kwargs
    ) -> Any:
        cache = self._caches["load_wasm"]
        key = make_cache_key(file_path, checksum)
        hit, value = cache.get(key)
        if hit:
            return value
        result = fallback(*args, **kwargs)
        cache.put(key, result)
        return result

    def metrics(self) -> dict:
        """Return per-cache and aggregate metrics."""
        per_op = {name: c.metrics() for name, c in self._caches.items()}
        total_hits = sum(v["hits"] for v in per_op.values())
        total_misses = sum(v["misses"] for v in per_op.values())
        total_lookups = total_hits + total_misses
        return {
            "per_operation": per_op,
            "aggregate": {
                "total_hits": total_hits,
                "total_misses": total_misses,
                "total_lookups": total_lookups,
                "overall_hit_rate": (
                    round(total_hits / total_lookups, 4) if total_lookups else 0.0
                ),
            },
        }

    def reset_all_metrics(self) -> None:
        for c in self._caches.values():
            c.reset_metrics()

    def purge_all_expired(self) -> Dict[str, int]:
        return {name: c.purge_expired() for name, c in self._caches.items()}

    def get_cache(self, name: str) -> LRUTTLCache:
        return self._caches[name]


# ── Module-level singleton ────────────────────────────────────────────────────

_DEFAULT_CACHE: Optional[CacheLayer] = None
_SINGLETON_LOCK = threading.Lock()


def get_default_cache() -> CacheLayer:
    """Return (or lazily create) the module-level default CacheLayer."""
    global _DEFAULT_CACHE
    if _DEFAULT_CACHE is None:
        with _SINGLETON_LOCK:
            if _DEFAULT_CACHE is None:
                _DEFAULT_CACHE = CacheLayer()
    return _DEFAULT_CACHE
