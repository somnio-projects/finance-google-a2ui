"""Gate and admin routes at the HTTP layer, with the flag service faked."""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_feature_flag_service
from app.api.feature_gate import require_feature
from app.core.errors import AuthorizationError


class FakeFlags:
    def __init__(self) -> None:
        self.state: dict[str, bool] = {}
        self.calls: list[tuple[str, bool]] = []

    async def is_enabled(self, key: str, *, default: bool = True) -> bool:
        self.calls.append((key, default))
        return self.state.get(key, default)

    async def list_flags(self, principal: object, *, request_id: str) -> list[object]:
        raise AuthorizationError("feature flags require the admin scope")

    async def set_flag(self, principal: object, **kwargs: object) -> object:
        raise AuthorizationError("feature flags require the admin scope")


@pytest.fixture
def flags() -> FakeFlags:
    return FakeFlags()


@pytest.fixture
def gated_client(app: FastAPI, flags: FakeFlags) -> Iterator[TestClient]:
    async def ping() -> dict[str, str]:
        return {"pong": "ok"}

    app.add_api_route(
        "/_test/ping", ping, dependencies=[require_feature("test.ping", default=False)]
    )
    app.dependency_overrides[get_feature_flag_service] = lambda: flags
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


def test_gate_answers_404_feature_disabled_when_off(
    gated_client: TestClient, flags: FakeFlags
) -> None:
    response = gated_client.get("/_test/ping")
    assert response.status_code == 404
    body = response.json()
    assert body["type"].endswith("/feature-disabled")
    assert body["request_id"] == response.headers["X-Request-ID"]
    assert flags.calls == [("test.ping", False)]


def test_gate_lets_request_through_when_on(
    gated_client: TestClient, flags: FakeFlags
) -> None:
    flags.state["test.ping"] = True
    assert gated_client.get("/_test/ping").json() == {"pong": "ok"}


def test_gated_me_audit_is_404_while_disabled_before_touching_the_database(
    gated_client: TestClient, flags: FakeFlags
) -> None:
    flags.state["identity.audit"] = False
    response = gated_client.get(
        "/v1/me/audit-events", headers={"Authorization": "Bearer good"}
    )
    assert response.status_code == 404
    assert response.json()["type"].endswith("/feature-disabled")


def test_admin_routes_translate_authorization_error_to_403(
    gated_client: TestClient,
) -> None:
    headers = {"Authorization": "Bearer good"}
    listed = gated_client.get("/v1/admin/feature-flags", headers=headers)
    assert listed.status_code == 403
    assert listed.json()["type"].endswith("/forbidden")
    updated = gated_client.put(
        "/v1/admin/feature-flags/x.read", json={"enabled": False}, headers=headers
    )
    assert updated.status_code == 403


@pytest.mark.parametrize(
    "key",
    ["UPPER.case", "has space", "ab", "x" * 101],
    ids=["upper", "space", "short", "long"],
)
def test_admin_put_rejects_invalid_keys_with_422(
    gated_client: TestClient, key: str
) -> None:
    response = gated_client.put(
        f"/v1/admin/feature-flags/{key}",
        json={"enabled": True},
        headers={"Authorization": "Bearer good"},
    )
    assert response.status_code == 422
    assert response.json()["type"].endswith("/malformed-request")


def test_admin_routes_require_a_token(gated_client: TestClient) -> None:
    assert gated_client.get("/v1/admin/feature-flags").status_code == 401
