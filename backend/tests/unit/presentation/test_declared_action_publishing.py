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
from app.presentation.catalog_json import snapshot_entry
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


def test_a_declared_action_reaches_every_rendering(
    declaring_projection: Projection,
) -> None:
    """AC-11 — one derivation, four renderings, compared instead of trusted.

    The title used to say four and the body asserted three. The missing one
    was `snapshot_entry`, which builds `docs/catalog/view-catalog.snapshot.json`
    — the artefact the Flutter client binds against, so the one rendering that
    could not describe a component's actions was the one the client reads
    (GGU-92). Nothing caught it because each artefact is diffed only against
    its own generator: both were internally consistent and disagreed.
    """
    projection = declaring_projection
    payload = _render_probe(sample_portfolio(), PrecisionOptions())

    in_payload = [ref.model_dump(mode="json") for ref in payload.actions]
    assert in_payload, "the probe must declare something for this to mean anything"

    #: Every rendering the one registration publishes to, named so a failure
    #: says which of them stopped agreeing rather than only that they differ.
    #: `.get` rather than `[...]`, so a rendering that drops the key entirely
    #: fails with the message below naming it, not with a bare ``KeyError``
    #: three frames deep. Dropping the key is the defect that actually
    #: happened (GGU-92), so it is the case worth diagnosing well.
    renderings = {
        "A2UI props": projection.surface(payload).props.get("actions"),
        "GET /v1/views": catalog_entry(projection).get("actions"),
        "view-catalog.snapshot.json": snapshot_entry(projection).get("actions"),
    }
    for name, rendered in renderings.items():
        assert rendered is not None, (
            f"{name} has no `actions` key at all, so it cannot describe what "
            f"this component declares — the renderings have drifted apart"
        )
        assert list(rendered) == in_payload, (
            f"{name} does not carry the action the payload declares; "
            f"the renderings have drifted apart"
        )

    assert ACTIONS.get(str(in_payload[0]["action"])) is DRILL
