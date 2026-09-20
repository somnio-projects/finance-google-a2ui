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
    assert {ALLOCATION, WATERFALL} <= {entry["id"] for entry in response.json()}


def test_the_views_routes_require_a_token(integration_client: TestClient) -> None:
    assert integration_client.get(VIEWS_URL).status_code == 401
    assert integration_client.get("/v1/views").status_code == 401


def test_a_batch_renders_across_entries_with_per_entry_status(
    integration_client: TestClient,
) -> None:
    """Spec 0012 AC-4, AC-5 — the real route, the real gates, one bad entry."""
    response = integration_client.post(
        "/v1/view-renders",
        json={
            "renders": [
                {"view": ALLOCATION},
                {"view": "nope.thing.v1"},
                {"view": WATERFALL},
            ]
        },
        headers=_headers(),
    )

    assert response.status_code == 201
    results = response.json()["results"]
    assert [entry["status"] for entry in results] == [200, 404, 200]
    assert results[0]["payload"]["total"]["amount"]["display"].startswith("$")
    assert results[1]["error"]["status"] == 404


def test_a_repeated_view_read_revalidates_to_304(
    integration_client: TestClient,
) -> None:
    """Spec 0012 AC-7 — end to end, including the feature gate and the DB."""
    headers = _headers()
    first = integration_client.get(f"{VIEWS_URL}?view={ALLOCATION}", headers=headers)
    etag = first.headers["ETag"]

    second = integration_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}",
        headers={**headers, "If-None-Match": etag},
    )

    assert second.status_code == 304
    assert second.content == b""
