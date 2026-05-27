"""In-process TTL caches for TMDB list endpoints.

One bucket per endpoint family — buckets have independent TTLs because the
freshness requirements differ (trending changes daily, now_playing barely
changes within a day).

If/when we run multiple API instances we'll swap the implementation for Redis
behind the same :func:`get_or_compute` interface. Callers don't care.
"""

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
    """Return cached value or compute + cache it.

    Raises KeyError if ``bucket`` was not declared in ``_caches``.
    """
    cache = _caches[bucket]
    try:
        return cache[key]
    except KeyError:
        value = fn()
        cache[key] = value
        return value


def clear(bucket: str | None = None) -> None:
    """Empty a bucket (or all of them). Mostly useful for tests."""
    if bucket is None:
        for c in _caches.values():
            c.clear()
    else:
        _caches[bucket].clear()
