"""Process-wide TTL cache for flag values (spec 0002, AC-5).

One instance lives in the ``Container``; the service reads through it so a
gated endpoint costs no database round-trip inside the TTL window.
"""

from datetime import datetime, timedelta

from app.core.protocols import Clock


class FeatureFlagCache:
    """Remember ``key -> enabled`` for ``ttl`` and forget on demand."""

    def __init__(self, *, ttl: timedelta, clock: Clock) -> None:
        """Create an empty cache with the given time-to-live."""
        self._ttl = ttl
        self._clock = clock
        self._entries: dict[str, tuple[bool, datetime]] = {}

    def get(self, key: str) -> bool | None:
        """Return the cached value, or ``None`` when absent or expired."""
        entry = self._entries.get(key)
        if entry is None:
            return None
        value, stored_at = entry
        if self._clock.now() - stored_at >= self._ttl:
            del self._entries[key]
            return None
        return value

    def put(self, key: str, value: bool) -> None:
        """Store ``value`` for ``key`` stamped with the current time."""
        self._entries[key] = (value, self._clock.now())

    def invalidate(self, key: str) -> None:
        """Forget ``key`` so the next read hits the database."""
        self._entries.pop(key, None)


__all__ = ["FeatureFlagCache"]
