# TMDB API endpoints to reach

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
        # full movie detail
        return self._get(f"/movie/{tmdb_id}", params={"language": language})

    def get_movie_credits(
        self, tmdb_id: int, *, language: str = "fr-FR"
    ) -> dict[str, Any]:
        # movie credits (cast & crew)
        return self._get(f"/movie/{tmdb_id}/credits", params={"language": language})

    def search_movies(
        self,
        query: str,
        *,
        page: int = 1,
        language: str = "fr-FR",
        include_adult: bool = False,
    ) -> dict[str, Any]:
        # search result
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
        # popular movies
        return self._get("/trending/movie/week", params={"language": language})

    def now_playing(
        self,
        *,
        region: str = "FR",
        page: int = 1,
        language: str = "fr-FR",
    ) -> dict[str, Any]:
        # movies currently in theaters
        return self._get(
            "/movie/now_playing",
            params={"region": region, "page": page, "language": language},
        )

    def list_genres(self, *, language: str = "fr-FR") -> dict[str, Any]:
        # known movie genders
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
    # reuses connections — keeping a single instance
    global _singleton
    if _singleton is None:
        _singleton = TMDBClient()
    return _singleton
