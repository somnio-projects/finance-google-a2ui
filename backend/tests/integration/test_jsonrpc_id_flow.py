"""GGU-164 (spec 0057) AC-1/AC-2 — a numeric id through the whole stack.

The unit suite swaps the dependencies; this one runs the real app against
PostgreSQL, because the 500 lived in the framework seam, not in a service.
"""

import uuid

import pytest
from fastapi.testclient import TestClient

from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND
from tests.conftest import make_token

ROUTES = ["/", "/a2ui/v1/a2a"]


def _headers() -> dict[str, str]:
    token = make_token(subject=f"user-{uuid.uuid4()}", ttl_seconds=10**9)
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.parametrize("route", ROUTES)
def test_a_numeric_id_is_echoed_as_a_number(
    integration_client: TestClient, route: str
) -> None:
    envelope = {"jsonrpc": "2.0", "id": 1, "method": "tasks/resubscribe"}

    response = integration_client.post(route, json=envelope, headers=_headers())

    assert response.status_code == 200
    assert response.json()["id"] == 1
    assert response.json()["error"]["code"] == METHOD_NOT_FOUND


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize(
    "rpc_id", ["x" * 129, 2**53], ids=["long-string", "int-too-big"]
)
def test_an_out_of_bounds_id_is_refused_in_the_envelope(
    integration_client: TestClient, route: str, rpc_id: object
) -> None:
    envelope = {"jsonrpc": "2.0", "id": rpc_id, "method": "tasks/resubscribe"}

    response = integration_client.post(route, json=envelope, headers=_headers())

    assert response.status_code == 200
    assert response.json()["error"]["code"] == INVALID_PARAMS
