"""AC-5 — what a ticket advertises as editable is what the backend enforces.

`.claude/rules/backend/testing.md` records this failure three times: a bound
written down, believed, and enforced by nothing. An interactive surface turns
it into a security surface rather than a nicety — it publishes to the widget
the values each field may hold, and a widget trusting "max 20" while the
backend accepts anything is the same hole with a form in front of it.

So the check walks the **registry**, not this one view: every projection that
publishes `TicketInput` descriptors is covered the day it registers. Each
descriptor's bound is fed back through `validated_options` — the same call the
HTTP path and the agent path make — and must agree with it: every advertised
value accepted, everything outside it rejected.
"""

import re
from typing import Any

import pytest

from app.core.errors import ValidationFailedError
from app.presentation.registry import REGISTRY, Projection
from app.presentation.resolve import validated_options
from app.presentation.sample import sample_portfolio
from app.presentation.tickets import TicketInput
from app.presentation.views.order_ticket import VIEW_ID

#: A pattern bounds a string only if it cannot match arbitrarily long input.
UNBOUNDED_QUANTIFIER = re.compile(r"[*+]")
#: Nothing any ticket bound admits, and long enough to expose a missing cap.
OUTSIDE = "☠" * 64


def _published() -> list[tuple[Projection, TicketInput]]:
    """Return every (projection, input) pair the registry really renders."""
    rows: list[tuple[Projection, TicketInput]] = []
    for projection in REGISTRY.all():
        payload = projection.render(sample_portfolio(), projection.options())
        rows.extend(
            (projection, field)
            for field in getattr(payload, "inputs", ())
            if isinstance(field, TicketInput)
        )
    return rows


INPUTS = _published()
CHOICES = [row for row in INPUTS if row[1].control == "choice"]
TEXTS = [row for row in INPUTS if row[1].control == "text"]


def _ids(rows: list[tuple[Projection, TicketInput]]) -> list[str]:
    """Name each case after the view and the option it covers."""
    return [f"{projection.id}.{field.option}" for projection, field in rows]


def _accepts(projection: Projection, option: str, value: str) -> bool:
    """Return True when the projection's own options model takes ``value``."""
    try:
        validated_options(projection, {option: value})
    except ValidationFailedError:
        return False
    return True


def _schema(projection: Projection, option: str) -> dict[str, Any]:
    """Return the JSON-schema fragment the options model publishes."""
    return projection.options.model_json_schema()["properties"][option]


@pytest.mark.parametrize(("projection", "field"), INPUTS, ids=_ids(INPUTS))
def test_the_value_an_input_starts_from_is_one_it_accepts_back(
    projection: Projection, field: TicketInput
) -> None:
    assert _accepts(projection, field.option, field.value)


@pytest.mark.parametrize(("projection", "field"), INPUTS, ids=_ids(INPUTS))
def test_a_value_outside_the_published_bound_is_rejected(
    projection: Projection, field: TicketInput
) -> None:
    with pytest.raises(ValidationFailedError, match=f"rejected option.*{field.option}"):
        validated_options(projection, {field.option: OUTSIDE})


@pytest.mark.parametrize(("projection", "field"), CHOICES, ids=_ids(CHOICES))
def test_every_choice_a_widget_is_offered_is_accepted(
    projection: Projection, field: TicketInput
) -> None:
    assert field.choices, "a choice control with no choices offers nothing"
    assert all(_accepts(projection, field.option, value) for value in field.choices)
    assert tuple(_schema(projection, field.option)["enum"]) == field.choices


@pytest.mark.parametrize(("projection", "field"), TEXTS, ids=_ids(TEXTS))
def test_a_text_bound_is_the_enforced_pattern_and_cannot_run_away(
    projection: Projection, field: TicketInput
) -> None:
    pattern = field.pattern
    assert pattern is not None, "a text control with no pattern publishes no bound"
    assert pattern == _schema(projection, field.option)["pattern"]
    assert pattern.startswith("^") and pattern.endswith("$")
    assert not UNBOUNDED_QUANTIFIER.search(pattern)


def test_the_check_bites_when_a_ticket_would_advertise_more_than_it_enforces() -> None:
    """A guard that passes everything guards nothing.

    Each value below is one a descriptor could plausibly have offered — a
    third side, a ninth decimal, a tenth integer digit — and the backend
    refuses all of them, which is what makes the cases above assertions
    rather than decoration.
    """
    ticket = REGISTRY.get(VIEW_ID)

    assert not _accepts(ticket, "side", "short")
    assert not _accepts(ticket, "symbol", "XRP")
    assert not _accepts(ticket, "size", "1.123456789")
    assert not _accepts(ticket, "size", "1234567890")
    assert _accepts(ticket, "size", "999999999.12345678")


def test_at_least_one_ticket_input_was_checked() -> None:
    """A registry that failed to load would make every case above vacuous."""
    assert INPUTS, "no ticket input was checked — did the registry load?"
