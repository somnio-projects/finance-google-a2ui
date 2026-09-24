"""AC-11..AC-13 of spec 0023 — a painter can actually draw every chart.

ADR-K D-5 settles the argument the design catalog raises: its schemas type
every figure as a bare ``number`` and its previews then show `+$3,240
(+0.68%)`, which would put the formatting in the client. The backend ships
**both** — the ``display`` string for every label a human reads, and the exact
figure beside it for geometry.

"Both" is only true if the raw half is actually there, and for the payoff
curve it was not: a point carried its price as a formatted ``label`` and
nothing else, so the x axis could be printed but not plotted. This file
asserts the property per chart, over the payload each one really renders.
"""

from decimal import Decimal

from app.domain.portfolio import Portfolio
from app.presentation.payoff_order import PayoffCurveOptions
from app.presentation.views.attribution_waterfall import (
    AttributionWaterfallOptions,
)
from app.presentation.views.attribution_waterfall import render as waterfall
from app.presentation.views.holdings_allocation import HoldingsAllocationOptions
from app.presentation.views.holdings_allocation import render as allocation
from app.presentation.views.payoff_curve import render as payoff


def test_the_payoff_curve_ships_both_coordinates_of_every_point(
    portfolio: Portfolio,
) -> None:
    """AC-11 — x and y are both exact figures, each with its own string."""
    payload = payoff(portfolio, PayoffCurveOptions())
    points = payload.series[0].points

    assert len(points) > 1, "a line needs more than one point"
    for point in points:
        assert isinstance(point.at.amount, Decimal)
        assert isinstance(point.value.amount, Decimal)
        # The label stays: it is the tick a widget prints, not the coordinate.
        assert point.label == point.at.display


def test_the_payoff_x_axis_is_ordered_and_spans_a_real_range(
    portfolio: Portfolio,
) -> None:
    """The raw x is usable as a domain, not merely present.

    A field that existed but repeated one value, or arrived unsorted, would
    satisfy a presence check and still be undrawable.
    """
    payload = payoff(portfolio, PayoffCurveOptions())
    xs = [point.at.amount for point in payload.series[0].points]

    assert xs == sorted(xs)
    assert xs[0] < xs[-1]
    assert len(set(xs)) == len(xs)


def test_the_waterfall_ships_the_running_totals_its_connectors_need(
    portfolio: Portfolio,
) -> None:
    """AC-12 — each step's exact delta and the exact total after it."""
    payload = waterfall(portfolio, AttributionWaterfallOptions())
    steps = payload.buckets

    assert steps
    running = payload.start.amount.amount
    for step in steps:
        running += step.delta.amount
        # The connector is drawn between consecutive cumulative levels, so the
        # walk has to close arithmetically on the raw values, not just look
        # right in the strings.
        assert step.cumulative.amount == running
    assert running == payload.end.amount.amount


def test_the_allocation_ships_the_exact_weights_a_donut_sweeps(
    portfolio: Portfolio,
) -> None:
    """AC-13 — arc angles come from the raw ratio, never from parsing "31.2%"."""
    payload = allocation(portfolio, HoldingsAllocationOptions())

    assert payload.categories
    total = sum(slice_.weight.value for slice_ in payload.categories)
    # The slices sweep the whole circle, to the last place Decimal division
    # keeps — an exact 1 would require the domain to round the weights, which
    # would put a rounded ratio into the geometry half of the ADR-E pair.
    assert abs(total - Decimal(1)) < Decimal("1e-25")
    for slice_ in payload.categories:
        assert Decimal(0) <= slice_.weight.value <= Decimal(1)
        assert isinstance(slice_.value.amount, Decimal)
