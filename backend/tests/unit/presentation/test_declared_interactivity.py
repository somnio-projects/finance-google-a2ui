"""GGU-78 — a component's two interactivity declarations must say the same thing.

A projection states what a caller may edit **twice**, in two places that were
never compared:

* the payload's own ``inputs[]`` descriptors — the controls the widget renders
  (spec 0018 OD-1);
* a payload field **named exactly as the option that sets it** — the rule
  `.claude/rules/backend/presentation.md` §4 calls "the interactivity
  declaration", and the only thing ``inventory`` reads to fill the ``Input``
  column of ``docs/catalog/CONTRACT.md`` and its index (spec 0019 OD-3).

They disagreed. ``order.ticket.v1`` offered four controls — ``symbol``,
``side``, ``size``, ``size_in`` — and the contract reported two, because the
first two happened to share a name with a payload field and the other two did
not (``size``'s field was called ``quantity``, and ``size_in`` had no field at
all). Nothing was wrong with either declaration on its own; nothing compared
them, so the document quietly under-reported what the component accepts, and a
client binding to the document could not know ``size`` was editable.

That is the defect this file exists to make impossible. The check walks the
**registry**, so the next component to get it wrong fails the gate rather than
shipping — and the failure names the projection and both sides of the
disagreement, because a bare set mismatch would send the reader hunting.
"""

from collections.abc import Mapping
from typing import Any

import pytest

from app.presentation.catalog_tables import interactive_fields, option_inputs
from app.presentation.inventory import inventory
from app.presentation.registry import REGISTRY, Projection
from app.presentation.resolve import validated_options
from app.presentation.sample import sample_portfolio
from app.presentation.tickets import TicketInput

PROJECTIONS = list(REGISTRY.all())
IDS = [projection.id for projection in PROJECTIONS]


def _offered(projection: Projection) -> set[str]:
    """Return the options this projection's payload offers as controls."""
    payload = projection.render(sample_portfolio(), projection.options())
    return {
        field.option
        for field in getattr(payload, "inputs", ())
        if isinstance(field, TicketInput)
    }


def _reported_paths(projection: Projection) -> tuple[str, ...]:
    """Return the field paths the generated contract marks editable.

    Built through the generator's own calls rather than by re-implementing the
    name match, so this test cannot pass a rule the document does not use.
    """
    fields = inventory(
        projection.dto.model_json_schema(),
        inputs=option_inputs(projection.options.model_json_schema()),
    )
    return interactive_fields(fields)


def _reported(projection: Projection) -> set[str]:
    """Return the *options* the contract reports as editable, by name."""
    return {path.rsplit(".", 1)[-1] for path in _reported_paths(projection)}


def _at(payload: Mapping[str, Any], path: str) -> Any:
    """Return the value a reported path points at in a rendered payload."""
    current: Any = payload
    for step in path.split("."):
        if step.endswith("[]"):
            current = current[step[:-2]]
            if not current:
                return None
            current = current[0]
        else:
            current = current[step]
    return current


def _disagreement(projection: Projection) -> str:
    """Spell out both declarations, so a failure needs no investigation."""
    return (
        f"{projection.id}: the payload offers controls for "
        f"{sorted(_offered(projection))} but the generated contract reports "
        f"{sorted(_reported(projection))} as editable "
        f"(paths {list(_reported_paths(projection))}). "
        "Name every editable payload field exactly as the option that sets it "
        "(presentation.md §4, spec 0019 OD-3)."
    )


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_every_control_a_payload_offers_is_reported_editable_by_the_contract(
    projection: Projection,
) -> None:
    """The GGU-78 defect: a control the document does not know about."""
    missing = _offered(projection) - _reported(projection)
    assert not missing, _disagreement(projection)


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_a_component_with_controls_reports_no_editable_field_it_cannot_offer(
    projection: Projection,
) -> None:
    """The other direction, for a component that has declared its controls.

    A projection publishing no ``inputs[]`` is not interactive and declares
    editability by naming alone (``scenario.comparison.v1`` does), so it has
    no second declaration to contradict. Once a component publishes one, the
    two must match exactly.
    """
    offered = _offered(projection)
    if not offered:
        pytest.skip("not an interactive component — no inputs[] to compare against")
    assert _reported(projection) == offered, _disagreement(projection)


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_every_field_the_contract_calls_editable_round_trips_through_its_option(
    projection: Projection,
) -> None:
    """A published input the options model refuses is a bound nobody enforces.

    Covers projections with no ``inputs[]`` too: the document's claim is
    checked against ``validated_options`` — the same call the HTTP path and
    the agent path make — for every projection in the registry.
    """
    example = projection.example
    for path in _reported_paths(projection):
        value = _at(example, path)
        option = path.rsplit(".", 1)[-1]
        validated_options(projection, {option: value})


def test_at_least_one_projection_offers_controls() -> None:
    """A registry that failed to load would make every case above vacuous."""
    assert any(_offered(projection) for projection in PROJECTIONS)
