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

import pytest

from app.presentation.catalog_doc import fields_of
from app.presentation.catalog_tables import READ_ONLY, inputs_note
from app.presentation.registry import Projection
from app.presentation.resolve import validated_options
from tests.unit.presentation.interactivity import (
    IDS,
    PROJECTIONS,
    disagreement,
    name_matched,
    offered,
    reported,
    reported_paths,
    value_at,
)


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_every_control_a_payload_offers_is_reported_editable_by_the_contract(
    projection: Projection,
) -> None:
    """The GGU-78 defect: a control the document does not know about."""
    missing = offered(projection) - reported(projection)
    assert not missing, disagreement(projection)


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
    controls = offered(projection)
    if not controls:
        pytest.skip("not an interactive component — no inputs[] to compare against")
    assert reported(projection) == controls, disagreement(projection)


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_the_contracts_read_only_claim_is_true_for_this_projection(
    projection: Projection,
) -> None:
    """The document's Inputs cell is checked, not merely its editable set.

    This is the case that has to bite for a **read-only** projection, and the
    first draft did not: it looped over the reported paths, so for four of the
    six registered projections its body never ran and the test passed by
    executing nothing. Asserting the *rendered claim* instead gives every
    projection a real assertion — `read-only` is a claim that can be wrong.
    """
    matched = name_matched(projection)
    claim = inputs_note(fields_of(projection))

    if not matched:
        assert claim == READ_ONLY, (
            f"{projection.id}: the contract claims {claim!r}, but no payload "
            "field is named after a declared option."
        )
        return
    assert claim != READ_ONLY, (
        f"{projection.id}: the contract claims read-only, but {sorted(matched)} "
        "name declared options and therefore round-trip (ADR-K D-3)."
    )
    assert reported(projection) == matched, disagreement(projection)


@pytest.mark.parametrize("projection", PROJECTIONS, ids=IDS)
def test_every_field_the_contract_calls_editable_round_trips_through_its_option(
    projection: Projection,
) -> None:
    """A published input the options model refuses is a bound nobody enforces.

    Vacuous by construction for a projection the contract calls read-only —
    there is nothing to round-trip — which is why the claim itself is asserted
    above and why ``test_the_registry_still_produces_both_kinds_of_case``
    guards the split.
    """
    example = projection.example
    for path in reported_paths(projection):
        value = value_at(example, path)
        option = path.rsplit(".", 1)[-1]
        validated_options(projection, {option: value})


def test_the_registry_still_produces_both_kinds_of_case() -> None:
    """Guard the split, so the cases above cannot all quietly go vacuous.

    Every assertion here is parametrised over the registry, so a registry that
    failed to load — or one where every projection drifted to the same shape —
    would turn the whole file green while checking nothing. This pins that at
    least one projection of **each** kind is present.
    """
    read_only = [p.id for p in PROJECTIONS if not name_matched(p)]
    editable = [p.id for p in PROJECTIONS if name_matched(p)]
    offering = [p.id for p in PROJECTIONS if offered(p)]

    assert read_only, "no read-only projection — the read-only claim is untested"
    assert editable, "no editable projection — the editable claim is untested"
    assert offering, "no projection offers controls — did the registry load?"
