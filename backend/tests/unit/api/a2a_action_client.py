"""The test client the A2A surface-action suites drive.

The **dispatcher** is overridden rather than the flag service alone, so this
stays a unit test: the real provider also reaches for an audit repository, and
`tests/unit/**` talks to nothing outside the process.

``_NoAudit`` raises rather than recording. Nothing in today's catalog declares
``audited=True``, so an audit write reaching it would mean an action started
recording taps without anyone deciding to — which is AC-10, asserted by
construction instead of by a counter nobody reads.
"""

from collections.abc import Iterator

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_surface_action_service
from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.services.surface_action_service import SurfaceActionService
from tests.conftest import FakeFlags, FakeReporter
from tests.unit.api.app_factory import make_app


class _NoAudit:
    """Nothing in today's catalog is audited, so nothing is ever written."""

    async def record(self, *args: object, **kwargs: object) -> None:
        """Fail loudly if an unaudited action ever reaches the audit trail."""
        del args, kwargs
        msg = "no shipped action declares audited=True (spec 0022 AC-10)"
        raise AssertionError(msg)


def actions_client_for(
    api_settings: Settings,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
    *,
    enabled: bool,
) -> Iterator[TestClient]:
    """Yield a client whose action dispatcher runs over fakes, flag set.

    Args:
        api_settings: The unit-test settings, with the unreachable DSN.
        principal: The verified caller every request resolves to.
        clock: The frozen clock.
        reporter: Telemetry sink the assertions read back.
        enabled: What `surface.actions` resolves to for this client.

    Yields:
        A client whose `POST /` accepts, or refuses, a `data` part.
    """
    app: FastAPI = make_app(
        api_settings, principal=principal, clock=clock, reporter=reporter
    )
    app.dependency_overrides[get_surface_action_service] = lambda: SurfaceActionService(
        flags=FakeFlags(enabled=enabled),  # type: ignore[arg-type]
        audit=_NoAudit(),  # type: ignore[arg-type]
        reporter=reporter,
    )
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


__all__ = ["actions_client_for"]
