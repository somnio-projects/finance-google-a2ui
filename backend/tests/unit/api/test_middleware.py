from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from app.api.middleware.security_headers import BASE_HEADERS, DOCS_CSP
from app.auth.principal import Principal
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings
from tests.unit.api.conftest import UNREACHABLE_DSN, make_app


def test_request_id_is_minted_and_echoed(client: TestClient) -> None:
    response = client.get("/healthz")
    assert len(response.headers["X-Request-ID"]) == 36


def test_request_id_from_client_is_reused_when_sane(client: TestClient) -> None:
    response = client.get("/healthz", headers={"X-Request-ID": "trace-123"})
    assert response.headers["X-Request-ID"] == "trace-123"


def test_request_id_from_client_is_replaced_when_too_long(client: TestClient) -> None:
    response = client.get("/healthz", headers={"X-Request-ID": "x" * 65})
    assert response.headers["X-Request-ID"] != "x" * 65


def test_security_headers_present_and_hsts_absent_outside_production(
    client: TestClient,
) -> None:
    response = client.get("/healthz")
    for name, value in BASE_HEADERS.items():
        assert response.headers[name] == value
    assert "Strict-Transport-Security" not in response.headers


def test_docs_page_gets_relaxed_csp(client: TestClient) -> None:
    assert client.get("/docs").headers["Content-Security-Policy"] == DOCS_CSP


def test_production_enables_hsts_and_hides_docs(
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> None:
    settings = make_settings(
        environment="production", database_url=UNREACHABLE_DSN, trusted_hosts=["*"]
    )
    app = make_app(settings, principal=principal, clock=clock, reporter=reporter)
    with TestClient(app) as client:
        response = client.get("/healthz")
        assert response.headers["Strict-Transport-Security"].startswith("max-age=")
        assert client.get("/docs").status_code == 404
        assert client.get("/openapi.json").status_code == 404


def test_body_limit_rejects_oversized_declared_length(client: TestClient) -> None:
    response = client.post(
        "/healthz", content=b"x" * 3000, headers={"Content-Length": "3000"}
    )
    assert response.status_code == 413
    assert response.json()["type"].endswith("/payload-too-large")


def test_body_limit_lets_small_bodies_through(client: TestClient) -> None:
    # 405 proves the request reached routing instead of being cut by the limit.
    assert client.post("/healthz", content=b"x" * 10).status_code == 405


def test_rate_limit_returns_429_after_budget_and_resets_next_window(
    client: TestClient, clock: FixedClock
) -> None:
    for _ in range(3):
        assert client.get("/v1/me").status_code == 401
    limited = client.get("/v1/me")
    assert limited.status_code == 429
    assert limited.headers["Retry-After"] == "60"
    assert limited.json()["type"].endswith("/rate-limited")
    clock._instant = FROZEN_NOW + timedelta(minutes=1)
    assert client.get("/v1/me").status_code == 401


def test_rate_limit_is_keyed_per_token_and_skips_health(client: TestClient) -> None:
    for _ in range(4):
        client.get("/v1/me", headers={"Authorization": "Bearer one"})
    assert (
        client.get("/v1/me", headers={"Authorization": "Bearer two"}).status_code == 401
    )
    assert client.get("/healthz").status_code == 200


@pytest.mark.parametrize(
    ("origin", "allowed"),
    [("http://localhost:3000", True), ("https://evil.test", False)],
    ids=["allowed_origin", "unlisted_origin"],
)
def test_cors_header_only_for_allowed_origins(
    client: TestClient, origin: str, allowed: bool
) -> None:
    response = client.get("/healthz", headers={"Origin": origin})
    assert ("access-control-allow-origin" in response.headers) is allowed


def test_untrusted_host_is_rejected(client: TestClient) -> None:
    response = client.get("/healthz", headers={"Host": "evil.test"})
    assert response.status_code == 400
