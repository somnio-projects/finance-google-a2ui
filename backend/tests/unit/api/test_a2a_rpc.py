"""Spec 0010 AC-2/AC-3/AC-4 — the JSON-RPC envelope and the event stream.

Everything here is the wire contract a client SDK codes against, which is why
it is asserted at the HTTP layer rather than on the service.
"""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.principal import Principal
from app.helpers.clock import FixedClock
from tests.conftest import FakeReporter
from tests.unit.api.a2a_envelopes import AUTH, CARD_URL, call, events, message
from tests.unit.api.conftest import make_session_app


def test_a_turn_without_a_token_is_refused(client: TestClient) -> None:
    """AC-4 — the protocol surface is authenticated; only the card is not."""
    response = client.post("/", json=call("message/stream", **message("hi")))

    assert response.status_code == 401
    assert response.json()["type"].endswith("auth/missing-token")


def test_a_turn_streams_a_working_status_then_the_answer(client: TestClient) -> None:
    """AC-2 — the event order a client SDK depends on."""
    response = client.post(
        "/", json=call("message/stream", **message("what do I hold?")), headers=AUTH
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    stream = events(response.text)
    assert [event["kind"] for event in stream] == [
        "status-update",
        "message",
        "status-update",
    ]
    assert stream[0]["status"] == {"state": "working"}
    assert stream[0]["final"] is False
    assert stream[-1]["final"] is True


def test_the_context_id_is_echoed_for_correlation(client: TestClient) -> None:
    """It is echoed, never trusted: history is GGU-46 (spec 0010 OD-2)."""
    response = client.post(
        "/",
        json=call("message/stream", **message("hello", context_id="ctx-42")),
        headers=AUTH,
    )

    assert {event["contextId"] for event in events(response.text)} == {"ctx-42"}


@pytest.fixture
def agent_off_client(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> Iterator[TestClient]:
    """The app with the agent's kill-switch thrown (`agent.a2a` forced off)."""
    app = make_session_app(
        principal, clock, reporter, feature_flags_force_disabled=["agent.a2a"]
    )
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


def test_the_turn_is_404_while_the_agent_flag_is_off(
    agent_off_client: TestClient,
) -> None:
    """The containment `INCIDENT_RESPONSE_PLAN.md` §4 promises must exist.

    The runbook's answer to a misbehaving endpoint is to flip its flag and get
    a 404 within the cache TTL. That worked on six `/v1` routers and not on
    the one surface that reaches the model.
    """
    response = agent_off_client.post(
        "/", json=call("message/stream", **message("what do I hold?")), headers=AUTH
    )

    assert response.status_code == 404
    assert response.json()["type"].endswith("/feature-disabled")


def test_the_agent_card_is_not_gated_by_the_agent_flag(
    agent_off_client: TestClient,
) -> None:
    """Deliberate: the card is the bootstrap document and stays reachable.

    Containment stops the *turn*, not discovery — a client still learns what
    this service is and then gets a 404 when it calls. Asserted so the
    asymmetry is a decision on the record rather than an oversight.
    """
    assert agent_off_client.get(CARD_URL).status_code == 200
