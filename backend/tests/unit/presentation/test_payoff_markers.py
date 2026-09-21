"""Spec 0024 §4 — the break-even is placeable without reading a label.

The defect these tests exist for is quiet: the client could find the
break-even only by comparing a rendered string against ``"Break-even price"``,
so the first payload rendered in another locale would drop the rule off the
chart with nothing going red. So the assertions below are about *addressing*,
not about arithmetic — the figures themselves are ``test_payoff_curve.py``'s.
"""

from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.payoff_order import PayoffCurveOptions
from app.presentation.payoff_payload import SECTIONS
from app.presentation.views.payoff_curve import render

ENTRY_SOL = "$528.00"


def options(**overrides: object) -> PayoffCurveOptions:
    return PayoffCurveOptions.model_validate(overrides)


def test_both_markers_are_reached_by_field_name(portfolio: Portfolio) -> None:
    """Each marker has a path of its own; there is no list to search."""
    markers = render(portfolio, options()).markers

    assert markers.break_even.at.display == ENTRY_SOL
    assert markers.current.at.display == ENTRY_SOL
    assert markers.break_even.at.amount == Decimal("528.00")


def test_a_marker_carries_the_exact_price_beside_the_string(
    portfolio: Portfolio,
) -> None:
    """The coordinate is a figure, so nothing parses `"$528.00"` back."""
    markers = render(portfolio, options(symbol="XOM")).markers

    assert markers.break_even.at.amount == Decimal("34.22")
    assert markers.break_even.at.display == "$34.22"


def test_relabelling_a_marker_does_not_move_it(portfolio: Portfolio) -> None:
    """The mutation check for N-5: the label is prose, the path is the address.

    A locale is the realistic way the label changes, and the point is that the
    two markers stay exactly where they were. Under the old shape this is the
    render where the break-even rule silently disappeared, because the string
    the client matched on no longer existed.
    """
    english = render(portfolio, options()).markers
    german = render(portfolio, options(locale="de-DE")).markers

    assert german.break_even.at.amount == english.break_even.at.amount
    assert german.current.at.amount == english.current.at.amount
    assert german.break_even.at.display == "528,00 $"


@pytest.mark.parametrize(
    "selected",
    [(), ("series",), ("totals", "series", "annotations")],
    ids=["nothing", "series-only", "everything"],
)
def test_fields_can_never_trim_the_markers(
    portfolio: Portfolio, selected: tuple[str, ...]
) -> None:
    """`markers` is outside `SECTIONS`, so no `fields` value can remove it.

    A client that can be served a payload without markers needs a fallback,
    and the only fallback available is the label match this block abolishes.
    """
    payload = render(portfolio, options(fields=selected))

    assert payload.markers.break_even.at.display == ENTRY_SOL
    assert "markers" not in SECTIONS
