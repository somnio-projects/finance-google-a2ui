"""Spec 0031 AC-1, OD-1, OD-4 — how ``order.ticket.v2`` is wired and named.

Split from ``test_order_ticket_v2`` for the file budget: that file is what the
payload *says*; this one is what the projection *is* — registered, guided,
named apart from v1, never auto-selected, and offering no way to place a trade.
"""

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.registry import REGISTRY
from app.presentation.views.order_ticket_v2 import (
    COMPONENT,
    DISCLOSURE,
    EFFECT,
    PROJECTION,
    VIEW_ID,
    OrderTicketV2Options,
    fitness,
    render,
    surface,
)


def test_the_ticket_declares_one_effect_and_no_way_to_place_an_order(
    portfolio: Portfolio,
) -> None:
    """0018 AC-8, again — there is no broker here, and the payload says so."""
    payload = render(portfolio, OrderTicketV2Options())
    props = surface(payload).props

    assert payload.effect == EFFECT == "recalculate"
    assert "broker" in DISCLOSURE and "nothing is ever sent" in DISCLOSURE
    assert set(payload.model_dump()).isdisjoint({"submit", "action", "order_id"})
    assert set(props).isdisjoint({"submit", "onSubmit", "endpoint", "href"})


def test_surface_maps_the_payload_onto_its_own_component(
    portfolio: Portfolio,
) -> None:
    """OD-1 — a second contract, a second name; `OrderTicket` stays with v1."""
    emitted = surface(render(portfolio, OrderTicketV2Options()))

    assert (emitted.component, emitted.view) == (COMPONENT, VIEW_ID)
    assert COMPONENT == "MultiLegOrderTicket"
    assert emitted.props["lines"][0]["increment"] == "BTC:0.07,ETH:1.0,SOL:16"
    assert emitted.props["constraints"]["breach"] == "none"


@pytest.mark.parametrize("subject", ["seeded", "empty"], ids=["seeded", "empty"])
def test_the_ticket_is_never_chosen_by_the_selection_rule(
    subject: str, portfolio: Portfolio, empty_portfolio: Portfolio
) -> None:
    """0018 OD-5 — a ticket answers an intent, never a shape of data."""
    assert fitness(portfolio if subject == "seeded" else empty_portfolio) == 0


def test_the_projection_is_registered_with_guidance_and_its_example() -> None:
    """AC-1 — removing the `register(...)` call must turn this red."""
    assert REGISTRY.get(VIEW_ID) is PROJECTION
    assert PROJECTION.example["view"] == VIEW_ID
    assert PROJECTION.guidance is not None
    assert "`draft_order`" in PROJECTION.guidance.use_when
