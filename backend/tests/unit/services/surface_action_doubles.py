"""Doubles and builders shared by the surface-action service tests.

Extracted so the test module stays inside the file budget and so a second
suite can reuse the same fakes rather than writing a third copy of them.
"""

from app.core.principal import Principal
from app.services.surface_action_service import SurfaceActionService
from tests.conftest import FakeFlags, FakeReporter


class EchoingFlags:
    """A flag service with no rows: every gate resolves to its own default.

    ``FakeFlags`` answers a fixed value and so cannot see which default the
    caller asked for. Dark-launching is exactly that argument, so it needs a
    double that returns it.
    """

    def __init__(self) -> None:
        self.asked: list[tuple[str, bool]] = []

    async def is_enabled(self, key: str, *, default: bool = True) -> bool:
        """Answer as the real service does when no row and no kill-switch apply."""
        self.asked.append((key, default))
        return default


class FakeAudit:
    """Records what would have been written to ``audit_events``."""

    def __init__(self) -> None:
        self.events: list[tuple[str, str | None]] = []

    async def record(
        self,
        principal: Principal,
        *,
        action: str,
        request_id: str,
        target: str | None = None,
    ) -> None:
        """Remember one event instead of persisting it."""
        del principal, request_id
        self.events.append((action, target))


def make_service(
    *, enabled: bool = True
) -> tuple[SurfaceActionService, FakeReporter, FakeAudit]:
    """Build the dispatcher over fakes, with the flag in a known state."""
    reporter = FakeReporter()
    audit = FakeAudit()
    service = SurfaceActionService(
        flags=FakeFlags(enabled=enabled),  # type: ignore[arg-type]
        audit=audit,  # type: ignore[arg-type]
        reporter=reporter,
    )
    return service, reporter, audit


__all__ = ["EchoingFlags", "FakeAudit", "make_service"]
