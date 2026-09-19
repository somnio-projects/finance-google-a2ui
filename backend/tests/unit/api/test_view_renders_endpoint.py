"""Spec 0012 AC-4, AC-5, AC-6 — the batch render resource at the HTTP layer.

The per-entry contract is what a client binds to, so it is asserted on the
wire: a batch containing a bad entry still answers 201, still renders the good
entries, and describes the bad one as a problem document inside its own result.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.presentation.registry import REGISTRY
from app.schemas.view_renders import MAX_OPTIONS, MAX_RENDERS

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"
BATCH_URL = "/v1/view-renders"
AUTH = {"Authorization": "Bearer good"}


def test_a_batch_renders_every_entry_in_one_round_trip(
    views_client: TestClient,
) -> None:
    response = views_client.post(
        BATCH_URL,
        json={"renders": [{"view": WATERFALL}, {"view": ALLOCATION}]},
        headers=AUTH,
    )

    assert response.status_code == 201
    results = response.json()["results"]
    assert [entry["view"] for entry in results] == [WATERFALL, ALLOCATION]
    assert [entry["status"] for entry in results] == [200, 200]
    assert results[1]["payload"]["view"] == ALLOCATION
    assert results[1]["portfolio_id"] == "current"


def test_a_created_batch_has_no_location_because_it_is_not_retrievable(
    views_client: TestClient,
) -> None:
    """Spec 0012 OD-1 — 201 as ADR-K D-18 says, without a lie in the header."""
    response = views_client.post(
        BATCH_URL, json={"renders": [{"view": ALLOCATION}]}, headers=AUTH
    )

    assert response.status_code == 201
    assert "Location" not in response.headers


def test_one_failing_entry_does_not_sink_the_others(
    views_client: TestClient,
) -> None:
    response = views_client.post(
        BATCH_URL,
        json={
            "renders": [
                {"view": "nope.thing.v1"},
                {"view": WATERFALL, "options": {"top_n": 3}},
                {"view": ALLOCATION},
            ]
        },
        headers=AUTH,
    )

    assert response.status_code == 201
    results = response.json()["results"]
    assert [entry["status"] for entry in results] == [404, 422, 200]
    assert results[0]["error"]["type"].endswith("/portfolio/unknown-view")
    assert results[1]["error"]["status"] == 422
    assert "payload" not in results[0]
    assert results[2]["payload"]["view"] == ALLOCATION


def test_a_declared_option_reaches_the_projection(views_client: TestClient) -> None:
    response = views_client.post(
        BATCH_URL,
        json={
            "renders": [
                {"view": ALLOCATION, "options": {"top_n": 1, "sort": "value_asc"}}
            ]
        },
        headers=AUTH,
    )

    categories = response.json()["results"][0]["payload"]["categories"]
    assert [row["key"] for row in categories] == ["DOGE", "other"]


@pytest.mark.parametrize(
    "body",
    [
        {"renders": []},
        {"renders": [{"view": ALLOCATION}] * (MAX_RENDERS + 1)},
        {"renders": [{"view": "NOT-AN-ID"}]},
        {"renders": [{"view": ALLOCATION, "nonsense": 1}]},
        {"renders": [{"view": ALLOCATION, "portfolio_id": "NOT VALID"}]},
        {
            "renders": [
                {
                    "view": ALLOCATION,
                    "options": {f"k{n}": n for n in range(MAX_OPTIONS + 1)},
                }
            ]
        },
        {"nonsense": []},
    ],
    ids=[
        "empty-batch",
        "over-the-cap",
        "malformed-view-id",
        "undeclared-entry-field",
        "malformed-portfolio-id",
        "too-many-options",
        "undeclared-body-field",
    ],
)
def test_a_malformed_batch_is_a_422_problem_document(
    views_client: TestClient, body: dict[str, object]
) -> None:
    """The batch's own bounds are the request's, not an entry's (AC-6)."""
    response = views_client.post(BATCH_URL, json=body, headers=AUTH)

    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["status"] == 422


def test_the_route_requires_a_token(views_client: TestClient) -> None:
    assert views_client.post(BATCH_URL, json={"renders": []}).status_code == 401


def test_the_operation_documents_the_union_and_both_examples(app: FastAPI) -> None:
    schema = app.openapi()
    operation = schema["paths"][BATCH_URL]["post"]
    request = operation["requestBody"]["content"]["application/json"]
    assert request["examples"]["mixed"]["value"]["renders"]
    assert operation["responses"]["201"]["content"]["application/json"]["example"]
    entry = schema["components"]["schemas"]["ViewRenderEntryResult"]["properties"]
    union = entry["payload"]["anyOf"][0]
    assert union["discriminator"]["propertyName"] == "view"
    for projection in REGISTRY.all():
        assert projection.id in union["discriminator"]["mapping"]


def test_the_catalog_advertises_the_batch_endpoint(views_client: TestClient) -> None:
    """A client discovers where a view can be rendered, not just that it exists."""
    catalog = views_client.get("/v1/views", headers=AUTH).json()

    for entry in catalog:
        assert BATCH_URL in " ".join(entry["endpoints"])
