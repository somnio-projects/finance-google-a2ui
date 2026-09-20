"""AC-11, AC-12 — a surface offers exactly the actions it declares.

Adding an action mechanism must not quietly give a component one. The check
walks the **registry** rather than naming the two surfaces that exist today,
so the guarantee holds for the next projection too:

* a projection that declares actions publishes the *same* declaration in its
  payload, in its A2UI props and in the ``/v1/views`` catalog entry — three
  copies of one fact, compared instead of trusted;
* a projection that declares none produces no actionable prop at all, and
  ``order.ticket.v1`` in particular still carries no submit, no endpoint and
  no callback (spec 0018 AC-8, re-asserted against this change).
"""

from typing import Any

import pytest

from app.actions.registry import ACTIONS
from app.presentation.contract import catalog_entry
from app.presentation.registry import REGISTRY, Projection
from app.presentation.sample import sample_portfolio

#: Props that would hand a widget a way to act that no action declares.
FORBIDDEN_PROPS = frozenset({"submit", "onSubmit", "endpoint", "href", "callback"})

PROJECTIONS = list(REGISTRY.all())
IDS = [projection.id for projection in PROJECTIONS]


def _payload(projection: Projection) -> Any:
    """Render the projection over the fixed sample portfolio."""
    return projection.render(sample_portfolio(), projection.options())


def _declared(projection: Projection) -> tuple[Any, ...]:
    """Return the action descriptors this projection's payload publishes."""
    return tuple(getattr(_payload(projection), "actions", ()))


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_a_surface_offers_no_action_prop_it_did_not_declare(
    projection: Projection,
) -> None:
    """AC-12 — the props follow the declaration, never lead it."""
    props = projection.surface(_payload(projection)).props
    offered = props.get("actions", [])

    assert set(props).isdisjoint(FORBIDDEN_PROPS), projection.id
    assert len(offered) == len(_declared(projection)), projection.id


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_every_declared_action_is_registered_and_published_alike(
    projection: Projection,
) -> None:
    """AC-11 — payload, props and catalog entry carry one derived fact."""
    payload = _payload(projection)
    props = projection.surface(payload).props
    entry = catalog_entry(projection)

    declared = getattr(payload, "actions", ())
    in_payload = [ref.model_dump(mode="json") for ref in declared]
    assert props.get("actions", []) == in_payload, projection.id
    assert list(entry["actions"]) == in_payload, projection.id
    for ref in in_payload:
        assert ACTIONS.get(str(ref["action"])), projection.id


def test_the_order_ticket_still_offers_no_way_to_place_an_order() -> None:
    """AC-12 — 0018 AC-8, re-asserted now that actions exist at all."""
    ticket = REGISTRY.get("order.ticket.v1")
    payload = _payload(ticket)
    props = ticket.surface(payload).props

    assert getattr(payload, "actions", ()) == ()
    assert "actions" not in props
    assert set(props).isdisjoint(FORBIDDEN_PROPS)
    assert set(payload.model_dump()).isdisjoint({"submit", "action", "order_id"})


def test_exactly_one_projection_declares_an_action_today() -> None:
    """A vacuity guard: the walk above proves nothing over an empty set."""
    declaring = [p.id for p in PROJECTIONS if _declared(p)]

    assert declaring == ["attribution.waterfall.v1"]
