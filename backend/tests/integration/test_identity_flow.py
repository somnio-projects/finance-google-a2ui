import uuid

from fastapi.testclient import TestClient

from tests.conftest import make_token


def test_readyz_is_ready_with_a_live_database(integration_client: TestClient) -> None:
    response = integration_client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "dependencies": [{"name": "database", "ready": True}],
    }


def test_me_returns_identity_and_records_audit_trail(
    integration_client: TestClient,
) -> None:
    subject = f"user-{uuid.uuid4()}"
    token = make_token(subject=subject, ttl_seconds=10**9, extra={"scope": "read"})
    headers = {"Authorization": f"Bearer {token}", "X-Request-ID": "it-req-1"}

    me = integration_client.get("/v1/me", headers=headers)
    assert me.status_code == 200
    assert me.json() == {
        "subject": subject,
        "provider": "jwt",
        "email": None,
        "scopes": ["read"],
    }
    assert token not in me.text

    audit = integration_client.get("/v1/me/audit-events?limit=5", headers=headers)
    assert audit.status_code == 200
    events = audit.json()
    assert len(events) == 1
    assert events[0]["action"] == "identity.read"
    assert events[0]["provider"] == "jwt"
    assert events[0]["request_id"] == "it-req-1"
    assert "token_fingerprint" not in events[0]


def test_audit_trail_is_isolated_per_subject(integration_client: TestClient) -> None:
    token_a = make_token(subject=f"a-{uuid.uuid4()}", ttl_seconds=10**9)
    token_b = make_token(subject=f"b-{uuid.uuid4()}", ttl_seconds=10**9)
    integration_client.get("/v1/me", headers={"Authorization": f"Bearer {token_a}"})
    integration_client.get("/v1/me", headers={"Authorization": f"Bearer {token_a}"})
    audit_b = integration_client.get(
        "/v1/me/audit-events", headers={"Authorization": f"Bearer {token_b}"}
    )
    assert audit_b.status_code == 200
    assert audit_b.json() == []


def test_expired_token_is_rejected_with_distinguishable_code(
    integration_client: TestClient,
) -> None:
    token = make_token(ttl_seconds=1)
    response = integration_client.get(
        "/v1/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 401
    assert response.json()["type"].endswith("/auth/expired-token")
