"""Thin sync HTTP client around the TMDB v3 API.

Auth uses the v4 Read Access Token (JWT) sent as ``Authorization: Bearer …``.
Methods return parsed JSON dicts as-is — translation to domain models happens
in the service layer.

Reference: https://developer.themoviedb.org/reference/intro/getting-started
"""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


# --------- exceptions ----------


class TMDBError(Exception):
    """Base class for all TMDB integration errors."""


class TMDBNotFound(TMDBError):
    """The requested resource does not exist on TMDB (HTTP 404)."""


class TMDBRateLimited(TMDBError):
    """TMDB rate limit reached (HTTP 429)."""


class TMDBUnavailable(TMDBError):
    """TMDB unreachable, timed out, or returned a 5xx."""


# --------- client ----------


_DEFAULT_TIMEOUT = httpx.Timeout(10.0, connect=5.0)


class TMDBClient:
    """Sync TMDB v3 client.

    Use as a context manager to release the underlying HTTP connection pool::

        with TMDBClient() as tmdb:
            movie = tmdb.get_movie(550)

    or rely on the module-level singleton via :func:`get_tmdb_client`.
    """

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: httpx.Timeout | None = None,
    ) -> None:
        self._client = httpx.Client(
            base_url=base_url or settings.tmdb_base_url,
            headers={
                "Authorization": f"Bearer {api_key or settings.tmdb_api_key}",
                "Accept": "application/json",
            },
            timeout=timeout or _DEFAULT_TIMEOUT,
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> TMDBClient:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    # ----- endpoints -----

    def get_movie(self, tmdb_id: int, *, language: str = "fr-FR") -> dict[str, Any]:
        """GET /movie/{movie_id} — full movie details."""
        return self._get(f"/movie/{tmdb_id}", params={"language": language})

    def get_movie_credits(
        self, tmdb_id: int, *, language: str = "fr-FR"
    ) -> dict[str, Any]:
        """GET /movie/{movie_id}/credits — cast + crew arrays."""
        return self._get(f"/movie/{tmdb_id}/credits", params={"language": language})

    def search_movies(
        self,
        query: str,
        *,
        page: int = 1,
        language: str = "fr-FR",
        include_adult: bool = False,
    ) -> dict[str, Any]:
        """GET /search/movie — search by title.

        Returns a paginated envelope ``{page, total_pages, total_results, results}``.
        """
        return self._get(
            "/search/movie",
            params={
                "query": query,
                "page": page,
                "language": language,
                "include_adult": str(include_adult).lower(),
            },
        )

    def trending(self, *, language: str = "fr-FR") -> dict[str, Any]:
        """GET /trending/movie/week — weekly trending.

        The time window is hardcoded to ``week`` per the design decision; if a
        ``day`` variant is needed later, add it as a new method.
        """
        return self._get("/trending/movie/week", params={"language": language})

    def now_playing(
        self,
        *,
        region: str = "FR",
        page: int = 1,
        language: str = "fr-FR",
    ) -> dict[str, Any]:
        """GET /movie/now_playing — movies currently in theaters in ``region``."""
        return self._get(
            "/movie/now_playing",
            params={"region": region, "page": page, "language": language},
        )

    def list_genres(self, *, language: str = "fr-FR") -> dict[str, Any]:
        """GET /genre/movie/list — the canonical TMDB movie genre list."""
        return self._get("/genre/movie/list", params={"language": language})

    # ----- internal -----

    def _get(self, path: str, *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        try:
            response = self._client.get(path, params=params)
        except httpx.TimeoutException as exc:
            logger.warning("TMDB timeout on %s: %s", path, exc)
            raise TMDBUnavailable(f"Timeout calling TMDB {path}") from exc
        except httpx.HTTPError as exc:
            logger.warning("TMDB network error on %s: %s", path, exc)
            raise TMDBUnavailable(f"Network error calling TMDB {path}") from exc

        if response.status_code == 404:
            raise TMDBNotFound(f"TMDB resource not found: {path}")
        if response.status_code == 429:
            retry_after = response.headers.get("retry-after")
            raise TMDBRateLimited(
                f"TMDB rate limit on {path}"
                + (f" (retry after {retry_after}s)" if retry_after else "")
            )
        if response.status_code >= 500:
            raise TMDBUnavailable(
                f"TMDB server error {response.status_code} on {path}"
            )
        if not response.is_success:
            raise TMDBError(
                f"TMDB returned {response.status_code} on {path}: "
                f"{response.text[:200]}"
            )
        return response.json()


# --------- module singleton ----------


_singleton: TMDBClient | None = None


def get_tmdb_client() -> TMDBClient:
    """Return a process-wide TMDBClient.

    httpx.Client is thread-safe and reuses connections — keeping a single
    instance avoids burning a new TCP handshake per request.
    """
    global _singleton
    if _singleton is None:
        _singleton = TMDBClient()
    return _singleton
