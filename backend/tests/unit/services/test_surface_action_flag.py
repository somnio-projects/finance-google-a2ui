"""AC-13, §9 — the capability is dark-launched off, and off means absent.

Separate from the resolution tests because it answers a different question:
not *what does a valid action become* but *may an action run at all*. The
first assertion is the one a database-backed test cannot honestly make —
"off by default" is a property of the call this service makes, and a test
that reads it from a stored row only holds while nobody has ever written one.
"""

import pytest

from app.core.errors import FeatureDisabledError
from app.core.principal import Principal
from app.schemas.a2a_parts import ActionData
from app.services.surface_action_service import FEATURE_KEY, SurfaceActionService
from tests.conftest import FakeReporter
from tests.unit.services.surface_action_doubles import (
    EchoingFlags,
    FakeAudit,
    make_service,
)

DRILL = "drill.attribution.v1"
REQUEST_ID = "req-7"


def _drill() -> ActionData:
    """Build the `data` part a waterfall tap would have sent."""
    return ActionData(action=DRILL, args={"driver": "DOGE"})


async def test_the_capability_is_dark_launched_off_when_no_row_exists() -> None:
    """AC-13, §9 — `surface.actions` is off until GGU-31/GGU-32 turn it on.

    Asserted here rather than against a database: "off by default" is a
    property of the call this service makes, and a test that reads it from a
    stored row only holds while nobody has ever written one.
    """
    flags = EchoingFlags()
    service = SurfaceActionService(
        flags=flags,  # type: ignore[arg-type]
        audit=FakeAudit(),  # type: ignore[arg-type]
        reporter=FakeReporter(),
    )

    assert await service.enabled() is False
    assert flags.asked == [(FEATURE_KEY, False)]


async def test_an_action_is_refused_outright_while_the_flag_is_off(
    principal: Principal,
) -> None:
    """AC-13 — a disabled capability is one that does not exist."""
    service, reporter, _ = make_service(enabled=False)

    assert not await service.enabled()
    with pytest.raises(FeatureDisabledError, match=FEATURE_KEY):
        await service.prompt_for(principal, _drill(), request_id=REQUEST_ID)

    assert reporter.metrics == []
