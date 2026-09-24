"""AC-11, AC-12 — a surface offers exactly the actions it declares, and no more.

Two halves, because while `surface.actions` ships **off** the registry alone
cannot prove either one:

* **Over the registry** — nothing advertises an action. That is AC-12, and it
  is the assertion that has to hold on `develop`: a declaration reaches the
  payload, the A2UI props, `GET /v1/views` and `docs/catalog/CONTRACT.md`,
  which #45/#48 hand to the client, so publishing one the service would refuse
  with `-32601` is worse than publishing none (`app.actions.capability`).
* **Over a projection registered here** that *does* declare an action — that
  is AC-11, and it proves the publishing pipeline end to end without waiting
  for GGU-31 to flip the constant. Asserting it over a registry where nothing
  declares an action would execute nothing, which is the defect this PR's own
  cross-declaration test was caught by.
"""

from typing import Any

import pytest

from app.actions.capability import SHIPPED_ENABLED
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

    assert set(props).isdisjoint(FORBIDDEN_PROPS), projection.id
    assert len(props.get("actions", [])) == len(_declared(projection)), projection.id


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_nothing_is_advertised_while_the_capability_ships_off(
    projection: Projection,
) -> None:
    """AC-12 — the catalogue must not describe what the service refuses.

    Deliberately asserted over *every* projection rather than the one that
    owns the action: the next surface to declare one while the flag is off
    should fail here.
    """
    if SHIPPED_ENABLED:  # pragma: no cover - flipped by GGU-31, not by a test
        pytest.skip("the capability ships enabled; declarations are expected")
    assert _declared(projection) == (), (
        f"{projection.id} publishes {[r.action for r in _declared(projection)]} "
        "while surface.actions ships off — a client binding to the catalogue "
        "would tap it and get -32601 (app.actions.capability)."
    )
    assert list(catalog_entry(projection)["actions"]) == []


def test_the_order_ticket_still_offers_no_way_to_place_an_order() -> None:
    """AC-12 — 0018 AC-8, re-asserted now that actions exist at all."""
    ticket = REGISTRY.get("order.ticket.v1")
    payload = _payload(ticket)
    props = ticket.surface(payload).props

    assert getattr(payload, "actions", ()) == ()
    assert "actions" not in props
    assert set(props).isdisjoint(FORBIDDEN_PROPS)
    assert set(payload.model_dump()).isdisjoint({"submit", "action", "order_id"})
