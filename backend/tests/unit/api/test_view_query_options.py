"""Every option the catalog advertises must be one the endpoint accepts.

`GET /v1/views` publishes each projection's options straight from its own
model (ADR-K D-8). `GET /v1/portfolios/{id}/views` binds `ViewQuery`, which
carries `extra="forbid"`. Those are **two declarations of one fact**, and
until this test nothing compared them.

What that cost: GGU-41 added four projections with nine options between them
and did not extend the query model, so the catalog advertised `symbol`,
`quantity`, `lot_method`, `methods`, `side`, `size`, `size_in`, `range_pct`
and `steps` while the endpoint answered **422** for every one. Four of six
projections were unreachable through the client-facing path. `POST
/v1/view-renders` served the identical options with a 201, because it forwards
them as a dict and lets the projection validate — which is how the gap was
isolated to the query model rather than the projections.

Nothing in the suite noticed. The projections were tested, the endpoint was
tested, the catalog was tested; the *relationship between them* was not.
"""

import pytest
from fastapi.testclient import TestClient

from app.presentation.registry import REGISTRY
from app.schemas.views import ViewQuery

#: Options the endpoint owns rather than any single projection.
ENVELOPE = {"view"}

PROJECTION_OPTIONS = sorted(
    {
        name
        for projection in REGISTRY.all()
        for name in projection.options.model_json_schema().get("properties", {})
    }
)


def test_at_least_one_projection_declares_options() -> None:
    """An empty registry would make every case below vacuous."""
    assert PROJECTION_OPTIONS


def test_view_query_accepts_every_registered_option() -> None:
    """The assertion that would have caught GGU-41's gap on the day it landed."""
    accepted = set(ViewQuery.model_fields) - ENVELOPE
    missing = sorted(set(PROJECTION_OPTIONS) - accepted)

    assert not missing, (
        "GET /v1/views advertises these options and the views endpoint would "
        f"answer 422 for them: {missing}. Add them to ProjectionOptions — the "
        "catalog is generated from the registry, so it cannot be the one that "
        "is wrong."
    )


@pytest.mark.parametrize("option", PROJECTION_OPTIONS, ids=PROJECTION_OPTIONS)
def test_every_advertised_option_is_a_real_query_parameter(
    option: str, client: TestClient
) -> None:
    """Not just declared on the model — actually bound by the live route.

    A field can exist on `ViewQuery` and still not reach the endpoint if the
    route stops binding the model. This sends the parameter and asserts the
    answer is not the "unknown parameter" 422.
    """
    view = next(
        projection.id
        for projection in REGISTRY.all()
        if option in projection.options.model_json_schema().get("properties", {})
    )
    # A whole query fragment, not a bare value: `methods` is a list and its
    # projection requires at least two distinct entries, so one of them is a
    # legitimate 422 from the view rather than the gap this test is about.
    fragment = {
        "symbol": "symbol=NVDA",
        "quantity": "quantity=0.5",
        "lot_method": "lot_method=FIFO",
        "methods": "methods=FIFO&methods=LIFO",
        "side": "side=buy",
        "size": "size=1",
        "size_in": "size_in=units",
        "range_pct": "range_pct=30",
        "steps": "steps=12",
        "top_n": "top_n=3",
        "include_other": "include_other=true",
        "sort": "sort=label",
        "precision": "precision=2",
        "locale": "locale=en-US",
        "currency": "currency=USD",
        "fields": "fields=buckets",
        "range": "range=1d",
        "group_by": "group_by=asset_class",
        "headline": "headline=false",
        "kind": "kind=dividend",
        "limit": "limit=50",
        "legs": "legs=NVDA:1",
    }[option]

    response = client.get(
        f"/v1/portfolios/current/views?view={view}&{fragment}",
        headers={"Authorization": "Bearer good"},
    )

    assert response.status_code != 422, (
        f"{fragment!r} is advertised by {view} and rejected by the "
        f"endpoint: {response.json()}"
    )


def test_an_option_no_projection_declares_is_still_refused(
    client: TestClient,
) -> None:
    """Widening the model must not have widened it to anything (ADR-K D-3)."""
    response = client.get(
        "/v1/portfolios/current/views?view=holdings.allocation.v1&nonsense=1",
        headers={"Authorization": "Bearer good"},
    )

    assert response.status_code == 422
