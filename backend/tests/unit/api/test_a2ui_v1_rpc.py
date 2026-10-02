"""Spec 0053 §3, AC-3, AC-5, AC-7 — ``POST /a2ui/v1/a2a`` over HTTP.

The service suites prove the routing; this one proves the route: bearer auth,
the event-stream media type, a JSON-RPC refusal at HTTP 200, the kill switch,
and — the one fact only HTTP can show — that a ``renderView`` payload is the
payload ``GET /v1/portfolios/current/views`` serves for the same options.
"""

from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.schemas.a2a import INVALID_PARAMS
from app.services.a2ui_v1_dispatch import CATALOG_REQUIRED
from tests.a2ui_v1_envelopes import prose, render_view
from tests.conftest import FakeReporter
from tests.unit.api.a2a_envelopes import AUTH, events
from tests.unit.api.conftest import make_session_app

RPC = "/a2ui/v1/a2a"


def test_a_v1_call_without_a_token_is_refused(client: TestClient) -> None:
    response = client.post(RPC, json=prose("hi"))

    assert response.status_code == 401
    assert response.json()["type"].endswith("auth/missing-token")


def test_a_v1_turn_streams_server_sent_events(client: TestClient) -> None:
    response = client.post(RPC, json=prose("what do I hold?"), headers=AUTH)

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    assert response.headers["cache-control"] == "no-store"
    assert [event["kind"] for event in events(response.text)] == [
        "status-update",
        "message",
        "status-update",
    ]


def test_a_renderer_without_the_catalog_is_a_json_rpc_error(
    client: TestClient,
) -> None:
    response = client.post(RPC, json=prose("hi", metadata={}), headers=AUTH)

    assert response.status_code == 200
    assert response.json()["error"] == {
        "code": INVALID_PARAMS,
        "message": CATALOG_REQUIRED,
    }


def test_a_non_json_body_is_a_json_rpc_error(client: TestClient) -> None:
    response = client.post(
        RPC, content=b"not json", headers={**AUTH, "Content-Type": "application/json"}
    )

    assert response.status_code == 200
    assert response.json()["error"]["code"] == INVALID_PARAMS


def test_render_view_payload_is_the_rest_payload(views_client: TestClient) -> None:
    """AC-3 — the v1.0 wire and the REST read cannot disagree about a figure."""
    streamed = views_client.post(RPC, json=render_view(), headers=AUTH)
    rest = views_client.get(
        "/v1/portfolios/current/views",
        params={"view": "portfolio.summary.v1", "range": "1y"},
        headers=AUTH,
    )

    answered: Any = events(streamed.text)[1]["artifact"]
    value = answered["parts"][0]["data"][1]["updateDataModel"]["value"]
    assert value["payload"] == rest.json()["views"]["portfolio.summary.v1"]


@pytest.fixture
def agent_off(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> Iterator[TestClient]:
    app = make_session_app(
        principal, clock, reporter, feature_flags_force_disabled=["agent.a2a"]
    )
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


def test_the_v1_route_shares_the_agent_kill_switch(agent_off: TestClient) -> None:
    response = agent_off.post(RPC, json=prose("hi"), headers=AUTH)

    assert response.status_code == 404
    assert response.json()["type"].endswith("feature-disabled")
