"""AC-3, AC-4, AC-5, AC-10, AC-13 — resolving an action into a turn.

The negative assertions carry the weight here. An argument value and the
composed prompt are the *conversation*; the action id is a registered
constant. Only the id may reach a metric or an audit row, and the test asserts
the recorded tags exactly rather than merely that the value is absent — a new
field cannot then be added silently (the rule ``agent_telemetry`` records).
"""

from collections.abc import Iterator
from typing import Any

import pytest

from app.actions.contracts import ActionArgs
from app.actions.errors import UnknownActionError
from app.actions.registry import ACTIONS, register
from app.actions.spec import SurfaceActionSpec
from app.core.errors import ValidationFailedError
from app.core.principal import Principal
from app.schemas.a2a_parts import ActionData
from app.services.surface_action_service import (
    ACCEPTED_METRIC,
    AUDIT_ACTION,
    REJECTED_METRIC,
)
from tests.unit.services.surface_action_doubles import (
    make_service,
)

DRILL = "drill.attribution.v1"
REQUEST_ID = "req-7"


def _data(action: str = DRILL, **args: Any) -> ActionData:
    """Build the `data` part a surface would have sent."""
    return ActionData(action=action, args=args or {"driver": "DOGE"})


@pytest.fixture
def audited_action() -> Iterator[str]:
    """Register an action that *does* declare an audit trail, then remove it.

    The two shipped actions decide nothing and record nothing, so the seam
    would otherwise be untested until the first action that needs it.
    """
    action_id = "decide.something.v1"
    spec = SurfaceActionSpec(
        id=action_id,
        label="Decide something",
        args=ActionArgs,
        prompt=lambda _: "decide something",
        audited=True,
    )
    register(spec)
    yield action_id
    ACTIONS.remove(action_id)


async def test_a_validated_action_becomes_the_server_composed_prompt(
    principal: Principal,
) -> None:
    """AC-3 — the turn receives backend text, never the caller's."""
    service, reporter, audit = make_service()

    prompt = await service.prompt_for(principal, _data(), request_id=REQUEST_ID)

    assert prompt == (
        "Break down the contribution of DOGE in more detail for the same "
        "window, and show the result."
    )
    assert reporter.metrics == [(ACCEPTED_METRIC, {"action": DRILL})]
    assert audit.events == []


async def test_an_unknown_action_is_rejected_before_the_turn(
    principal: Principal,
) -> None:
    """AC-4 — the client cannot name a behaviour that does not exist."""
    service, reporter, _ = make_service()

    with pytest.raises(UnknownActionError, match="is not registered"):
        await service.prompt_for(principal, _data("no.such.v1"), request_id=REQUEST_ID)

    assert reporter.metrics == [(REJECTED_METRIC, {"action": "no.such.v1"})]


async def test_an_out_of_range_argument_is_rejected_and_counted(
    principal: Principal,
) -> None:
    """AC-5 — rejection is terminal; there is no fallback turn."""
    service, reporter, _ = make_service()

    with pytest.raises(ValidationFailedError, match=r"rejected argument.*driver"):
        await service.prompt_for(principal, _data(driver="XRP"), request_id=REQUEST_ID)

    assert reporter.metrics == [(REJECTED_METRIC, {"action": DRILL})]


async def test_no_telemetry_carries_an_argument_value_or_the_prompt(
    principal: Principal,
) -> None:
    """AC-10 — the tag set is asserted exactly, not merely checked for absence."""
    service, reporter, _ = make_service()

    await service.prompt_for(principal, _data(driver="SOL"), request_id=REQUEST_ID)

    assert [tags for _, tags in reporter.metrics] == [{"action": DRILL}]
    assert all("SOL" not in str(tags) for _, tags in reporter.metrics)


async def test_the_shipped_actions_record_no_audit_event(
    principal: Principal,
) -> None:
    """AC-10 — a tap decides nothing, so it must not bury the identity trail."""
    service, _, audit = make_service()

    await service.prompt_for(principal, _data(), request_id=REQUEST_ID)

    assert audit.events == []


async def test_an_audited_action_records_exactly_one_event(
    principal: Principal, audited_action: str
) -> None:
    """AC-10 — the seam works, so the first deciding action inherits a trail."""
    service, _, audit = make_service()

    await service.prompt_for(
        principal, ActionData(action=audited_action), request_id=REQUEST_ID
    )

    assert audit.events == [(AUDIT_ACTION, audited_action)]
