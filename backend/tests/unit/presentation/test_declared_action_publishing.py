"""AC-11 — a declared action reaches all four renderings from one derivation.

Proven over a projection registered **here**, not over the shipped registry.
While `surface.actions` ships off nothing in the catalogue declares an action
(`app.actions.capability`), so asserting this over `REGISTRY.all()` would loop
zero times and pass by executing nothing — the exact defect the reviewer found
in the first draft of `test_declared_interactivity.py`.
"""

from collections.abc import Iterator
from typing import Literal

import pytest
from pydantic import Field

from app.actions.declared import SurfaceActionRef, declared_action
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.actions.registry import ACTIONS
from app.domain.portfolio import Portfolio
from app.presentation.contract import catalog_entry
from app.presentation.fragments import ProjectionDto
from app.presentation.options import PrecisionOptions
from app.presentation.registry import REGISTRY, Projection, register
from app.presentation.sample import sample_portfolio
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

PROBE_VIEW = "probe.actionable.v1"


class _ProbePayload(ProjectionDto):
    """A payload that declares the drill action, whatever the flag says."""

    view: Literal["probe.actionable.v1"] = Field(
        default=PROBE_VIEW,
        description="Projection discriminator.",
        examples=[PROBE_VIEW],
    )
    actions: tuple[SurfaceActionRef, ...] = Field(
        default=(), description="What tapping this surface may send back."
    )


def _render_probe(portfolio: Portfolio, options: PrecisionOptions) -> _ProbePayload:
    """Render the probe with one declared action."""
    del portfolio, options
    return _ProbePayload(actions=(declared_action(DRILL),))


def _surface_probe(payload: _ProbePayload) -> Surface:
    """Map the probe's declaration into its A2UI props."""
    return Surface(
        component="Probe",
        view=payload.view,
        title="Probe",
        props={"actions": [ref.model_dump(mode="json") for ref in payload.actions]},
    )


@pytest.fixture
def declaring_projection() -> Iterator[Projection]:
    """Register a projection that declares an action, then remove it."""
    spec = ProjectionSpec(
        id=PROBE_VIEW,
        summary="A probe that declares an action, to prove the pipeline.",
        endpoints=("GET /v1/portfolios/{portfolio_id}/views",),
        options=PrecisionOptions,
        dto=_ProbePayload,
        render=_render_probe,
        surface=_surface_probe,
        fitness=lambda _: 0,
    )
    register(spec)
    yield spec
    REGISTRY.remove(PROBE_VIEW)


def test_a_declared_action_reaches_the_payload_the_props_and_the_catalog(
    declaring_projection: Projection,
) -> None:
    """AC-11 — one derivation, three renderings, compared instead of trusted."""
    projection = declaring_projection
    payload = _render_probe(sample_portfolio(), PrecisionOptions())
    props = projection.surface(payload).props
    entry = catalog_entry(projection)

    in_payload = [ref.model_dump(mode="json") for ref in payload.actions]
    assert in_payload, "the probe must declare something for this to mean anything"
    assert props["actions"] == in_payload
    assert list(entry["actions"]) == in_payload
    assert ACTIONS.get(str(in_payload[0]["action"])) is DRILL
