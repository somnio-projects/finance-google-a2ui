"""AC-13, §9 — the capability is dark-launched off, and off means absent.

Separate from the resolution tests because it answers a different question:
not *what does a valid action become* but *may an action run at all*. The
first assertion is the one a database-backed test cannot honestly make —
"off by default" is a property of the call this service makes, and a test
that reads it from a stored row only holds while nobody has ever written one.
"""

import pytest

from app.actions.capability import SHIPPED_ENABLED
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
    return ActionData(action=DRILL, args={"driver": "LINK"})


async def test_the_capability_ships_on_when_no_row_exists() -> None:
    """0022 AC-13 as amended by 0029 — `surface.actions` ships **on**.

    Asserted here rather than against a database: the default is a property
    of the call this service makes, and a test that reads it from a stored
    row only holds while nobody has ever written one. The admin API can still
    turn it off; ``SHIPPED_ENABLED`` is what it resolves to before anyone has.
    """
    flags = EchoingFlags()
    service = SurfaceActionService(
        flags=flags,  # type: ignore[arg-type]
        audit=FakeAudit(),  # type: ignore[arg-type]
        reporter=FakeReporter(),
    )

    assert await service.enabled() is SHIPPED_ENABLED
    assert flags.asked == [(FEATURE_KEY, SHIPPED_ENABLED)]


async def test_an_action_is_refused_outright_while_the_flag_is_off(
    principal: Principal,
) -> None:
    """AC-13 — a disabled capability is one that does not exist."""
    service, reporter, _ = make_service(enabled=False)

    assert not await service.enabled()
    with pytest.raises(FeatureDisabledError, match=FEATURE_KEY):
        await service.prompt_for(principal, _drill(), request_id=REQUEST_ID)

    assert reporter.metrics == []
