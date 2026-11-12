"""GGU-164 (spec 0057) AC-1/AC-2 — the id is echoed with its JSON type, on both wires.

``POST /`` (v0.9) and ``POST /a2ui/v1/a2a`` (v1.0) share one envelope, so both
are driven by the same cases. An unknown method answers with the id and needs
no flag or model, which makes it the smallest probe of the echo.
"""

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.schemas.a2a import INVALID_PARAMS, MAX_SAFE_INT, METHOD_NOT_FOUND
from tests.unit.api.a2a_envelopes import AUTH

ROUTES = ["/", "/a2ui/v1/a2a"]


def _post(client: TestClient, route: str, rpc_id: object) -> dict[str, Any]:
    envelope = {"jsonrpc": "2.0", "id": rpc_id, "method": "tasks/resubscribe"}
    response = client.post(route, json=envelope, headers=AUTH)
    assert response.status_code == 200
    return response.json()


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize(
    "rpc_id",
    ["req-1", 1, -3, MAX_SAFE_INT, None],
    ids=["str", "int", "neg", "max", "null"],
)
def test_the_id_is_echoed_with_the_type_it_was_sent_in(
    client: TestClient, route: str, rpc_id: object
) -> None:
    body = _post(client, route, rpc_id)

    assert body["error"]["code"] == METHOD_NOT_FOUND
    assert body["id"] == rpc_id
    assert type(body["id"]) is type(rpc_id)


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize(
    "rpc_id",
    ["x" * 129, MAX_SAFE_INT + 1, -MAX_SAFE_INT - 1, True],
    ids=["long-string", "int-too-big", "int-too-small", "bool"],
)
def test_an_id_out_of_bounds_is_a_json_rpc_error_never_a_500(
    client: TestClient, route: str, rpc_id: object
) -> None:
    body = _post(client, route, rpc_id)

    assert body["error"]["code"] == INVALID_PARAMS
    assert body["id"] is None
