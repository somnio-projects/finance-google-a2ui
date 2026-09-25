"""AC-3..AC-5, AC-13 — a surface action on the wire (spec 0022 §3.2).

Asserted at the HTTP layer because this *is* the wire contract: which status,
which error code, which shape. Two things a reader should take from it:

* a refused action never opens the stream — it is a JSON-RPC error object at
  **HTTP 200**, the shape a client already parses;
* with `surface.actions` off, a `data` part is `-32601` and text behaves
  exactly as it did before GGU-78.
"""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND
from app.services.a2a_actions import ACTIONS_DISABLED, UNKNOWN_ACTION
from tests.conftest import FakeReporter
from tests.unit.api.a2a_action_client import actions_client_for
from tests.unit.api.a2a_envelopes import AUTH, action_message, call, events, message

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


@pytest.fixture
def actions_off_client(
    api_settings: Settings,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> Iterator[TestClient]:
    """A client with `surface.actions` off — the shipped default."""
    yield from actions_client_for(
        api_settings, principal, clock, reporter, enabled=False
    )


def _error(response: object) -> dict[str, object]:
    """Return the JSON-RPC error object of a refusal."""
    return response.json()["error"]  # type: ignore[attr-defined,no-any-return]


def test_a_data_part_runs_a_turn_and_streams_the_documented_events(
    actions_client: TestClient,
) -> None:
    """AC-3 — an action is a turn, and it streams like any other."""
    response = actions_client.post(
        "/",
        json=call("message/stream", **action_message(DRILL, {"driver": "LINK"})),
        headers=AUTH,
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    assert [event["kind"] for event in events(response.text)] == [
        "status-update",
        "message",
        "status-update",
    ]


def test_an_unknown_action_is_a_json_rpc_error_at_http_200(
    actions_client: TestClient,
) -> None:
    """AC-4 — the stream never opens; there is no fallback turn."""
    response = actions_client.post(
        "/", json=call("message/stream", **action_message("no.such.v1")), headers=AUTH
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    assert _error(response) == {"code": INVALID_PARAMS, "message": UNKNOWN_ACTION}


def test_a_rejection_names_the_argument_and_never_its_value(
    actions_client: TestClient,
) -> None:
    """AC-5 — an echoed input is how a rejection becomes a reflection vector."""
    response = actions_client.post(
        "/",
        json=call("message/stream", **action_message(DRILL, {"driver": "XRP"})),
        headers=AUTH,
    )

    detail = str(_error(response)["message"])
    assert _error(response)["code"] == INVALID_PARAMS
    assert "driver" in detail
    assert "XRP" not in detail


def test_a_data_part_is_method_not_found_while_the_flag_is_off(
    actions_off_client: TestClient,
) -> None:
    """AC-13 — a disabled capability is one that does not exist."""
    response = actions_off_client.post(
        "/", json=call("message/stream", **action_message(DRILL)), headers=AUTH
    )

    assert response.status_code == 200
    assert _error(response) == {
        "code": METHOD_NOT_FOUND,
        "message": ACTIONS_DISABLED,
    }


def test_prose_is_unchanged_while_the_flag_is_off(
    actions_off_client: TestClient,
) -> None:
    """AC-13 — every other A2A behaviour is byte-identical to before."""
    response = actions_off_client.post(
        "/", json=call("message/stream", **message("what do I hold?")), headers=AUTH
    )

    assert response.status_code == 200
    assert [event["kind"] for event in events(response.text)] == [
        "status-update",
        "message",
        "status-update",
    ]
