"""AC-6, AC-7, AC-8 end to end — real app, real PostgreSQL, real feature gates.

The unit suite fakes the flag service; here the gates resolve against the
migrated database exactly as in production, so this is what proves the routes
are reachable with nothing overridden.
"""

import uuid

from fastapi.testclient import TestClient

from tests.conftest import make_token

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"
VIEWS_URL = "/v1/portfolios/current/views"


def _headers() -> dict[str, str]:
    token = make_token(subject=f"user-{uuid.uuid4()}", ttl_seconds=10**9)
    return {"Authorization": f"Bearer {token}"}


def test_portfolio_views_returns_two_projections_in_one_request(
    integration_client: TestClient,
) -> None:
    response = integration_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}&view={WATERFALL}", headers=_headers()
    )
    assert response.status_code == 200
    body = response.json()
    assert set(body["views"]) == {ALLOCATION, WATERFALL}
    assert body["views"][ALLOCATION]["total"]["amount"]["display"].startswith("$")
    assert body["views"][WATERFALL]["buckets"]


def test_the_same_session_answers_the_same_numbers_twice(
    integration_client: TestClient,
) -> None:
    headers = _headers()
    first = integration_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=headers)
    second = integration_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=headers)
    assert first.json() == second.json()


def test_an_option_the_view_does_not_declare_is_422(
    integration_client: TestClient,
) -> None:
    response = integration_client.get(
        f"{VIEWS_URL}?view={WATERFALL}&top_n=3", headers=_headers()
    )
    assert response.status_code == 422
    assert response.json()["type"].endswith("/validation-failed")


def test_the_catalog_is_served(integration_client: TestClient) -> None:
    response = integration_client.get("/v1/views", headers=_headers())
    assert response.status_code == 200
    assert {entry["id"] for entry in response.json()} == {ALLOCATION, WATERFALL}


def test_the_views_routes_require_a_token(integration_client: TestClient) -> None:
    assert integration_client.get(VIEWS_URL).status_code == 401
    assert integration_client.get("/v1/views").status_code == 401
