"""AC-13 — adding a chart edits no shared file (ADR-K D-15), proven.

This test *is* the guardrail. It defines a brand new projection inside itself
— id, options model, DTO, render, A2UI adapter, fitness — registers it, and
then checks it reached every consumer: the registry, the ``/v1/views``
catalog, the generated prompt fragments and the discriminated union. Nothing
under ``src/`` is touched to make that happen.

If a future refactor reintroduces a central list, an enum or an ``if/elif``
that a new chart must be added to, this test goes red first.
"""

from collections.abc import Iterator
from decimal import Decimal
from typing import Literal

import pytest
from fastapi.testclient import TestClient
from pydantic import Field

from app.domain.portfolio import Portfolio
from app.presentation.contract import views_response_model
from app.presentation.fragments import ProjectionDto, Total, money
from app.presentation.options import PrecisionOptions
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import REGISTRY, register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

NEW_VIEW = "cash.runway.v1"


class CashRunwayOptions(PrecisionOptions):
    """The only knob the new chart declares."""


class CashRunwayPayload(ProjectionDto):
    """A chart nobody had thought of when the registry was written."""

    view: Literal["cash.runway.v1"] = Field(
        default=NEW_VIEW, description="Projection discriminator.", examples=[NEW_VIEW]
    )
    headline: Total = Field(description="The one figure this chart shows.")


def render_runway(
    portfolio: Portfolio, options: CashRunwayOptions
) -> CashRunwayPayload:
    """Render the new chart — pure, like every other one."""
    total = sum((row.market_value for row in portfolio.holdings()), Decimal(0))
    return CashRunwayPayload(
        headline=Total(label="Runway", amount=money(total, precision=options.precision))
    )


def surface_runway(payload: CashRunwayPayload) -> Surface:
    """Map the new payload onto its A2UI component."""
    return Surface(
        component="StatCard",
        view=payload.view,
        title=payload.headline.label,
        props={"value": payload.headline.amount.display},
    )


@pytest.fixture
def new_projection() -> Iterator[ProjectionSpec]:
    """Register the test's own projection and take it back out afterwards."""
    spec = ProjectionSpec(
        id=NEW_VIEW,
        summary="Cash runway — a chart added without editing a shared file.",
        endpoints=("GET /v1/portfolios/{portfolio_id}/views",),
        options=CashRunwayOptions,
        dto=CashRunwayPayload,
        render=render_runway,
        surface=surface_runway,
        fitness=lambda _: 0,
    )
    register(spec)
    yield spec
    REGISTRY.remove(NEW_VIEW)


def test_a_projection_defined_in_a_test_reaches_every_consumer(
    new_projection: ProjectionSpec, views_client: TestClient
) -> None:
    assert REGISTRY.get(NEW_VIEW) is new_projection

    response = views_client.get("/v1/views", headers={"Authorization": "Bearer good"})
    assert response.status_code == 200
    catalog = response.json()
    entry = next(row for row in catalog if row["id"] == NEW_VIEW)
    assert entry["summary"] == new_projection.summary
    assert "precision" in entry["options_schema"]["properties"]
    assert entry["example"]["view"] == NEW_VIEW

    fragments = prompt_fragment(REGISTRY.all())
    assert f"- {NEW_VIEW} — {new_projection.summary}" in fragments
    assert "precision (integer 0..8)" in fragments

    union = views_response_model(REGISTRY.all(), name="Probe").model_json_schema()
    mapping = union["properties"]["views"]["additionalProperties"]["discriminator"]
    assert NEW_VIEW in mapping["mapping"]
