import pytest
from fastapi.testclient import TestClient

from tests.conftest import FakeReporter


def test_me_without_token_is_401_missing_token(
    client: TestClient, reporter: FakeReporter
) -> None:
    response = client.get("/v1/me")
    assert response.status_code == 401
    assert response.headers["content-type"].startswith("application/problem+json")
    body = response.json()
    assert body["type"].endswith("/auth/missing-token")
    assert body["status"] == 401
    assert body["instance"] == "/v1/me"
    assert body["request_id"] == response.headers["X-Request-ID"]
    assert ("auth.rejected", {"code": "missing-token"}) in reporter.metrics


@pytest.mark.parametrize(
    "header", ["Bearer bad", "Basic abc"], ids=["rejected_token", "wrong_scheme"]
)
def test_me_with_bad_credentials_is_401_without_internal_detail(
    client: TestClient, header: str
) -> None:
    response = client.get("/v1/me", headers={"Authorization": header})
    assert response.status_code == 401
    body = response.json()
    assert body["type"].startswith("https://errors.finance-a2ui/auth/")
    assert "Traceback" not in response.text
    assert "jwt" not in body["detail"].lower()


def test_me_audit_rejects_out_of_range_limit_before_hitting_the_database(
    client: TestClient,
) -> None:
    response = client.get(
        "/v1/me/audit-events?limit=0", headers={"Authorization": "Bearer good"}
    )
    assert response.status_code == 422
    body = response.json()
    assert body["type"].endswith("/malformed-request")
    assert "1 request field" in body["detail"]
