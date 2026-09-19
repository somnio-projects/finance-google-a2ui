import uuid

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.bootstrap import build_container, create_app
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings, make_token

FLAGS = "/v1/admin/feature-flags"


def _admin_headers() -> dict[str, str]:
    token = make_token(
        subject=f"admin-{uuid.uuid4()}", ttl_seconds=10**9, extra={"roles": ["admin"]}
    )
    return {"Authorization": f"Bearer {token}"}


def _user_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {make_token(ttl_seconds=10**9)}"}


def test_toggle_disables_and_restores_gated_endpoint(
    integration_client: TestClient,
) -> None:
    user, admin = _user_headers(), _admin_headers()
    assert integration_client.get("/v1/me/audit", headers=user).status_code == 200

    off = integration_client.put(
        f"{FLAGS}/identity.audit",
        json={"enabled": False, "description": "demo rehearsal"},
        headers=admin,
    )
    assert off.status_code == 200
    assert off.json()["enabled"] is False
    disabled = integration_client.get("/v1/me/audit", headers=user)
    assert disabled.status_code == 404
    assert disabled.json()["type"].endswith("/feature-disabled")

    on = integration_client.put(
        f"{FLAGS}/identity.audit", json={"enabled": True}, headers=admin
    )
    assert on.json()["enabled"] is True
    assert on.json()["description"] == "demo rehearsal"
    assert integration_client.get("/v1/me/audit", headers=user).status_code == 200


def test_toggle_persists_flag_and_audit_rows(integration_client: TestClient) -> None:
    admin = _admin_headers()
    key = f"demo.{uuid.uuid4().hex[:8]}"
    integration_client.put(
        f"{FLAGS}/{key}",
        json={"enabled": False},
        headers={**admin, "X-Request-ID": "ff-1"},
    )
    listed = integration_client.get(FLAGS, headers=admin)
    assert listed.status_code == 200
    assert any(f["key"] == key and f["enabled"] is False for f in listed.json())
    audit = integration_client.get("/v1/me/audit", headers=admin)
    actions = [e["action"] for e in audit.json()]
    assert f"feature_flag.update:{key}" in actions
    assert any(e["request_id"] == "ff-1" for e in audit.json())


def test_admin_routes_require_admin_scope(integration_client: TestClient) -> None:
    user = _user_headers()
    assert integration_client.get(FLAGS, headers=user).status_code == 403
    denied = integration_client.put(
        f"{FLAGS}/x.read", json={"enabled": True}, headers=user
    )
    assert denied.status_code == 403
    assert denied.json()["type"].endswith("/forbidden")


def test_invalid_key_is_422(integration_client: TestClient) -> None:
    response = integration_client.put(
        f"{FLAGS}/Not-Valid", json={"enabled": True}, headers=_admin_headers()
    )
    assert response.status_code == 422


def test_force_disabled_env_wins_over_database(
    database_url: str, integration_reporter: FakeReporter
) -> None:
    settings = make_settings(
        database_url=database_url,
        trusted_hosts=["*"],
        feature_flags_force_disabled=["identity.audit"],
    )
    app: FastAPI = create_app(
        settings,
        container=build_container(
            settings, clock=FixedClock(FROZEN_NOW), reporter=integration_reporter
        ),
    )
    with TestClient(app) as client:
        admin = _admin_headers()
        on = client.put(
            f"{FLAGS}/identity.audit", json={"enabled": True}, headers=admin
        )
        assert on.status_code == 200
        assert on.json()["enabled"] is False  # kill-switch reflected in the response
        assert client.get("/v1/me/audit", headers=admin).status_code == 404
