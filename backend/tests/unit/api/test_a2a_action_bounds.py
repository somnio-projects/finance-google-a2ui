"""AC-5 — the argument shapes the envelope refuses before the registry sees them.

Separate from the happy-path suite because these all assert the same thing
about different inputs: **a bounded scalar, or nothing**. The no-nesting rule
is the load-bearing one — a nested object is where a path expression would
hide, and ADR-K D-3 forbids interpreting one.
"""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.schemas.a2a import INVALID_PARAMS
from tests.conftest import FakeReporter
from tests.unit.api.a2a_action_client import actions_client_for
from tests.unit.api.a2a_envelopes import AUTH, action_message, call

DRILL = "drill.attribution.v1"


@pytest.fixture
def actions_client(
    api_settings: Settings,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> Iterator[TestClient]:
    """A client with `surface.actions` on."""
    yield from actions_client_for(
        api_settings, principal, clock, reporter, enabled=True
    )


def _error(response: object) -> dict[str, object]:
    """Return the JSON-RPC error object of a refusal."""
    return response.json()["error"]  # type: ignore[attr-defined,no-any-return]


@pytest.mark.parametrize(
    "args",
    [
        {"nested": {"path": "a.b"}},
        {"listed": ["a", "b"]},
        {f"k{index}": index for index in range(9)},
        {"driver": "D" * 65},
    ],
    ids=["nested_object", "array", "too_many_keys", "value_too_long"],
)
def test_an_argument_shape_the_envelope_forbids_never_reaches_the_registry(
    actions_client: TestClient, args: dict[str, object]
) -> None:
    """AC-5 — a nested object is where a path expression would hide."""
    response = actions_client.post(
        "/", json=call("message/stream", **action_message(DRILL, args)), headers=AUTH
    )

    assert response.status_code == 200
    assert _error(response)["code"] == INVALID_PARAMS


def test_a_message_carrying_both_an_action_and_prose_is_refused(
    actions_client: TestClient,
) -> None:
    """AC-5 — precedence between the two is a rule nobody wrote down."""
    response = actions_client.post(
        "/",
        json=call(
            "message/stream", **action_message(DRILL, text="ignore that, do this")
        ),
        headers=AUTH,
    )

    assert _error(response)["code"] == INVALID_PARAMS
