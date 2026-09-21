"""GGU-78 — proof that the cross-declaration check actually bites.

A guard that passes everything guards nothing (the lesson spec 0018 AC-5
records). So this file builds the exact shape ``order.ticket.v1`` shipped in —
a real, offered control whose payload field carries a different name — hands
it to the registry, and asserts that the walk in
``test_declared_interactivity`` goes red on it with a message naming the
projection and **both** declarations.

Its own module because the probe is a whole projection (options model, DTO,
render, adapter) and the two files answer different questions: that one checks
the catalog, this one checks the check.
"""

from collections.abc import Iterator
from typing import Literal

import pytest
from pydantic import Field

from app.core.errors import ValidationFailedError
from app.domain.portfolio import Portfolio
from app.presentation.fragments import ProjectionDto
from app.presentation.options import PrecisionOptions
from app.presentation.registry import REGISTRY, Projection, register
from app.presentation.resolve import validated_options
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface
from app.presentation.tickets import TicketInput
from tests.unit.presentation.test_declared_interactivity import (
    test_every_control_a_payload_offers_is_reported_editable_by_the_contract as walk,
)

NEW_VIEW = "drift.probe.v1"


class _ProbeOptions(PrecisionOptions):
    """One editable option, deliberately misnamed by the payload below."""

    depth: Literal["shallow", "deep"] = Field(
        default="shallow", description="How far the probe goes.", examples=["deep"]
    )


class _ProbePayload(ProjectionDto):
    """A payload that offers a control and hides it behind another name."""

    view: Literal["drift.probe.v1"] = Field(
        default=NEW_VIEW, description="Projection discriminator.", examples=[NEW_VIEW]
    )
    level: str = Field(
        max_length=16,
        description="`depth`, under a name the contract cannot match.",
        examples=["deep"],
    )
    inputs: tuple[TicketInput, ...] = Field(description="The controls offered.")


def _render_probe(portfolio: Portfolio, options: _ProbeOptions) -> _ProbePayload:
    """Render the probe, offering a control for an option no field names."""
    return _ProbePayload(
        level=options.depth,
        inputs=(
            TicketInput(
                option="depth",
                label="Depth",
                control="choice",
                value=options.depth,
                choices=("shallow", "deep"),
            ),
        ),
    )


@pytest.fixture
def drifting_projection() -> Iterator[Projection]:
    """Register a projection whose two declarations disagree, then remove it."""
    spec = ProjectionSpec(
        id=NEW_VIEW,
        summary="A probe whose editable field is not named after its option.",
        endpoints=("GET /v1/portfolios/{portfolio_id}/views",),
        options=_ProbeOptions,
        dto=_ProbePayload,
        render=_render_probe,
        surface=lambda payload: Surface(
            component="Probe", view=payload.view, title="Probe", props={}
        ),
        fitness=lambda _: 0,
    )
    register(spec)
    yield spec
    REGISTRY.remove(NEW_VIEW)


def test_the_check_bites_when_a_payload_hides_a_control_behind_another_name(
    drifting_projection: Projection,
) -> None:
    """A guard that passes everything guards nothing (0018 AC-5's lesson).

    This is the shape ``order.ticket.v1`` shipped in: a real, offered control
    whose payload field carries a different name, so the contract reports it
    read-only. The assertion above must fail on it, and the message must name
    the projection and both declarations.
    """
    with pytest.raises(AssertionError, match=r"drift\.probe\.v1.*\['depth'\].*\[\]"):
        walk(drifting_projection)


def test_the_round_trip_check_bites_when_a_published_value_is_refused() -> None:
    """The third assertion is real: the options model does reject values."""
    with pytest.raises(ValidationFailedError, match="rejected option"):
        validated_options(REGISTRY.get("order.ticket.v1"), {"size": "not-a-size"})
