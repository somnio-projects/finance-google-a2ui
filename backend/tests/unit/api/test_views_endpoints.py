"""AC-6, AC-7, AC-8 — the two view routes at the HTTP layer (spec 0005).

The view routes touch no database, but their feature gates do, so the flag
service is faked (``views_client``) and the DSN stays unreachable. Everything
asserted here is the wire contract: statuses, problem documents and the shape
the Flutter client binds.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.container import Container
from app.api.deps import get_render_intent_service, get_view_service
from app.presentation.registry import REGISTRY
from app.schemas.views import MAX_VIEWS

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"
VIEWS_URL = "/v1/portfolios/current/views"
AUTH = {"Authorization": "Bearer good"}


def test_two_views_are_rendered_in_one_request(views_client: TestClient) -> None:
    response = views_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}&view={WATERFALL}", headers=AUTH
    )
    assert response.status_code == 200
    body = response.json()
    assert set(body["views"]) == {ALLOCATION, WATERFALL}
    assert body["views"][ALLOCATION]["view"] == ALLOCATION
    assert body["views"][WATERFALL]["view"] == WATERFALL
    assert body["portfolio_id"] == "current"
    assert body["views"][ALLOCATION]["total"]["amount"]["display"] == "$65,038.60"


def test_a_declared_option_reaches_the_projection(views_client: TestClient) -> None:
    response = views_client.get(
        f"{VIEWS_URL}?view={ALLOCATION}&top_n=1&sort=value_asc", headers=AUTH
    )
    assert response.status_code == 200
    categories = response.json()["views"][ALLOCATION]["categories"]
    assert [row["key"] for row in categories] == ["DOGE", "other"]


def test_no_view_lets_the_selection_rule_choose(views_client: TestClient) -> None:
    body = views_client.get(VIEWS_URL, headers=AUTH).json()
    assert list(body["views"]) == [WATERFALL]


@pytest.mark.parametrize(
    "query",
    [
        "?nonsense=1",
        "?currency=EUR",
        "?precision=99",
        f"?view={WATERFALL}&top_n=3",
        "?view=" + "&view=".join([ALLOCATION] * (MAX_VIEWS + 1)),
        "?view=NOT-AN-ID",
    ],
    ids=[
        "undeclared-parameter",
        "out-of-range-currency",
        "out-of-range-precision",
        "option-the-view-does-not-declare",
        "too-many-views",
        "malformed-view-id",
    ],
)
def test_a_bad_option_is_a_422_problem_document(
    views_client: TestClient, query: str
) -> None:
    response = views_client.get(f"{VIEWS_URL}{query}", headers=AUTH)
    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["status"] == 422


def test_an_unknown_view_id_is_a_404_problem_document(
    views_client: TestClient,
) -> None:
    response = views_client.get(f"{VIEWS_URL}?view=nope.thing.v1", headers=AUTH)
    assert response.status_code == 404
    assert response.json()["type"].endswith("/portfolio/unknown-view")


def test_another_portfolio_is_a_404(views_client: TestClient) -> None:
    response = views_client.get("/v1/portfolios/someone-else/views", headers=AUTH)
    assert response.status_code == 404
    assert response.json()["type"].endswith("/not-found")


def test_the_routes_require_a_token(views_client: TestClient) -> None:
    assert views_client.get(VIEWS_URL).status_code == 401
    assert views_client.get("/v1/views").status_code == 401


def test_catalog_describes_every_registered_projection(
    views_client: TestClient,
) -> None:
    response = views_client.get("/v1/views", headers=AUTH)
    assert response.status_code == 200
    catalog = response.json()
    assert {WATERFALL, ALLOCATION} <= {entry["id"] for entry in catalog}
    for entry, projection in zip(catalog, REGISTRY.all(), strict=True):
        assert entry["endpoints"] == list(projection.endpoints)
        assert entry["options_schema"]["properties"]
        assert entry["example"]["view"] == entry["id"]


def test_the_operation_documents_the_union_and_one_example_per_view(
    app: FastAPI,
) -> None:
    schema = app.openapi()
    operation = schema["paths"]["/v1/portfolios/{portfolio_id}/views"]["get"]
    examples = operation["responses"]["200"]["content"]["application/json"]["examples"]
    assert set(examples) == {projection.id for projection in REGISTRY.all()}
    union = schema["components"]["schemas"]["PortfolioViews"]["properties"]["views"]
    assert union["additionalProperties"]["discriminator"]["propertyName"] == "view"


def test_the_providers_build_both_services(app: FastAPI) -> None:
    container: Container = app.state.container
    assert get_view_service(container).surface  # the renderer is wired
    assert get_render_intent_service(container) is not None
