"""Spec 0053 AC-1, AC-3, AC-5, AC-6 — the three demo flows on the v1.0 wire.

The whole stack: real PostgreSQL, the real feature flags, the scripted model
client the factory selects without a key (spec 0033), the real tools and the
real registry. Every emitted part validates against the vendored schemas, and
every surface's payload is the payload the REST read serves for the same view
and options **from the same database row**.
"""

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.infra.model.demo_script import FLOW_A, FLOW_B, FLOW_C
from tests.a2ui_v1_envelopes import drill, prose, render_view
from tests.a2ui_v1_schemas import errors
from tests.conftest import make_token
from tests.unit.api.a2a_envelopes import events

RPC = "/a2ui/v1/a2a"
VIEWS = "/v1/portfolios/current/views"

#: What each design flow draws, by the tool the script calls (spec 0033).
FLOWS = {
    FLOW_A: ("attribution.window.v1", "AttributionWaterfall"),
    FLOW_B: ("taxlots.table.v1", "TaxLotTable"),
    FLOW_C: ("order.ticket.v2", "MultiLegOrderTicket"),
}


@pytest.fixture
def headers() -> dict[str, str]:
    """A fresh subject per test, so its portfolio is its own."""
    token = make_token(subject=f"user-{uuid.uuid4()}", ttl_seconds=10**9)
    return {"Authorization": f"Bearer {token}"}


def _parts(stream: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        event["artifact"]["parts"][0]
        for event in stream
        if event["kind"] == "artifact-update"
    ]


def _rest(
    client: TestClient, headers: dict[str, str], view: str, options: dict[str, Any]
) -> dict[str, Any]:
    response = client.get(VIEWS, params={"view": view, **options}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()["views"][view]


@pytest.mark.parametrize("flow", sorted(FLOWS), ids=["flow-a", "flow-b", "flow-c"])
def test_a_demo_flow_streams_its_surface_as_v1(
    integration_client: TestClient, headers: dict[str, str], flow: str
) -> None:
    response = integration_client.post(RPC, json=prose(flow), headers=headers)

    assert response.status_code == 200
    stream = events(response.text)
    kinds = [event["kind"] for event in stream]
    assert kinds[0] == "status-update"
    assert kinds[-2:] == ["message", "status-update"]
    (part,) = _parts(stream)
    assert errors("agent_to_renderer_list.json", part["data"]) == []
    surface = part["data"][0]["createSurface"]
    view, component = FLOWS[flow]
    assert surface["components"][0]["component"] == component
    root = surface["dataModel"]["root"]
    assert root["view"] == view
    assert root["payload"] == _rest(integration_client, headers, view, root["options"])
    assert "renderIntents" not in stream[-2]


def test_render_view_reaches_the_database_and_not_the_model(
    integration_client: TestClient, headers: dict[str, str]
) -> None:
    response = integration_client.post(RPC, json=render_view(), headers=headers)

    (part,) = _parts(events(response.text))
    assert errors("agent_to_renderer_list.json", part["data"]) == []
    value = part["data"][1]["updateDataModel"]["value"]
    assert value["payload"] == _rest(
        integration_client, headers, "portfolio.summary.v1", {"range": "1y"}
    )


def test_the_drill_action_runs_the_composed_turn(
    integration_client: TestClient, headers: dict[str, str]
) -> None:
    response = integration_client.post(RPC, json=drill(driver="BTC"), headers=headers)

    assert response.status_code == 200
    stream = events(response.text)
    assert stream[0]["status"] == {"state": "working"}
    (part,) = _parts(stream)
    assert errors("agent_to_renderer_list.json", part["data"]) == []
    surface = part["data"][0]["createSurface"]
    assert surface["components"][0]["component"] == "DriverDetail"
    assert surface["dataModel"]["root"]["options"] == {"symbol": "BTC"}
    assert stream[-1]["final"] is True
