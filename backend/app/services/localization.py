"""Helpers to resolve a user's language into stored content rows.

Content tables key on a 2-char ``language_iso`` (e.g. ``fr``), while users carry
a BCP-47-ish tag (``fr-FR``). TMDB calls use the full tag; storage uses iso2.
"""

from __future__ import annotations

from typing import Protocol, TypeVar

DEFAULT_FALLBACK_ISO = "en"


def to_iso2(language: str | None) -> str:
    # 'fr-FR' -> 'fr', 'en' -> 'en', None -> 'en'
    if not language:
        return DEFAULT_FALLBACK_ISO
    return language.split("-")[0].lower()


class _HasLanguageIso(Protocol):
    language_iso: str


T = TypeVar("T", bound=_HasLanguageIso)


def pick_content(contents: list[T], lang_iso: str) -> T | None:
    """Pick the content row for ``lang_iso``, fall back to en, then first available."""
    if not contents:
        return None
    by_lang = {c.language_iso: c for c in contents}
    return (
        by_lang.get(lang_iso)
        or by_lang.get(DEFAULT_FALLBACK_ISO)
        or contents[0]
    )
