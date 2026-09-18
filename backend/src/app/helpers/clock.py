"""Clock implementations satisfying ``app.core.protocols.Clock``."""

from datetime import UTC, datetime, timedelta


class SystemClock:
    """Real wall clock, always UTC-aware."""

    def now(self) -> datetime:
        """Return the current UTC time."""
        return datetime.now(tz=UTC)


class FixedClock:
    """Clock frozen at a given instant — for deterministic tests and demos."""

    def __init__(self, instant: datetime) -> None:
        """Freeze the clock at ``instant`` (must be timezone-aware)."""
        if instant.tzinfo is None:
            msg = f"FixedClock requires an aware datetime, got {instant!r}"
            raise ValueError(msg)
        self._instant = instant

    def now(self) -> datetime:
        """Return the frozen instant."""
        return self._instant

    def advance(self, delta: timedelta) -> None:
        """Move the frozen instant forward by ``delta`` (tests only)."""
        self._instant = self._instant + delta


__all__ = ["FixedClock", "SystemClock"]
