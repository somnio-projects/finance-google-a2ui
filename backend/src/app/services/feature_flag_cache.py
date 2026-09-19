"""Process-wide TTL cache for flag values (spec 0002, AC-5).

One instance lives in the ``Container``; the service reads through it so a
gated endpoint costs no database round-trip inside the TTL window.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.core.protocols import Clock


@dataclass(frozen=True, slots=True)
class _CacheEntry:
    """One remembered flag value and when it was stored."""

    value: bool
    stored_at: datetime


class FeatureFlagCache:
    """Remember ``key -> enabled`` for ``ttl`` and forget on demand.

    ``get`` is a pure query: an expired entry simply reads as absent and is
    replaced by the next ``put``; nothing mutates while reading.
    """

    def __init__(self, *, ttl: timedelta, clock: Clock) -> None:
        """Create an empty cache with the given time-to-live."""
        self._ttl = ttl
        self._clock = clock
        self._entries: dict[str, _CacheEntry] = {}

    def _is_live(self, entry: _CacheEntry) -> bool:
        """Return True while ``entry`` is inside the time-to-live."""
        return self._clock.now() - entry.stored_at < self._ttl

    def get(self, key: str) -> bool | None:
        """Return the cached value, or ``None`` when absent or expired."""
        entry = self._entries.get(key)
        if entry is None or not self._is_live(entry):
            return None
        return entry.value

    def put(self, key: str, value: bool) -> None:
        """Store ``value`` for ``key`` stamped with the current time."""
        self._entries[key] = _CacheEntry(value=value, stored_at=self._clock.now())

    def invalidate(self, key: str) -> None:
        """Forget ``key`` so the next read hits the database."""
        self._entries.pop(key, None)


__all__ = ["FeatureFlagCache"]
