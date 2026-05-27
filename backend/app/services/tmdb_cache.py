from __future__ import annotations

from collections.abc import Callable, Hashable
from typing import Any

from cachetools import TTLCache

_caches: dict[str, TTLCache] = {
    # bucket    : maxsize  ttl(seconds)
    "trending":   TTLCache(maxsize=8,   ttl=600),    # 10 min
    "search":     TTLCache(maxsize=256, ttl=600),    # 10 min
    "now_playing": TTLCache(maxsize=64, ttl=1800),   # 30 min
}


def get_or_compute(
    bucket: str, key: Hashable, fn: Callable[[], Any]
) -> Any:
    # Return cached value or compute + cache it
    cache = _caches[bucket]
    try:
        return cache[key]
    # Raises KeyError if bucket was not declared in _caches
    except KeyError:
        value = fn()
        cache[key] = value
        return value


def clear(bucket: str | None = None) -> None:
    # Empty a bucket (or all of them)
    if bucket is None:
        for c in _caches.values():
            c.clear()
    else:
        _caches[bucket].clear()
