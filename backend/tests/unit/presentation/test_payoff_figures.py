"""Spec 0016 AC-4/AC-5 — one price resolution, and the fragments built on it.

``price_places`` is the rule that stops a payoff ladder contradicting itself
(spec 0014 OD-10): every assertion here is about a price a reader could
otherwise read two ways.
"""

from decimal import Decimal

import pytest

from app.core.display import price_display
from app.domain.payoff_pricing import payoff_curve
from app.presentation import payoff_figures as figures

EN_US = "en-US"


def make_curve(*, entry: str, range_pct: int = 30, steps: int = 12, side: str = "buy"):
    return payoff_curve(
        symbol="SOL",
        name="Vanguard S&P 500 ETF",
        entry_price=Decimal(entry),
        quantity=Decimal(10),
        side=side,  # type: ignore[arg-type]
        range_pct=range_pct,
        steps=steps,
    )


def shape(places: int, precision: int = 2) -> figures.Shape:
    return figures.Shape(places=places, precision=precision, locale=EN_US)


@pytest.mark.parametrize(
    ("step", "entry", "expected"),
    [
        ("3.81", "152.40", 2),
        ("79.5125", "3180.50", 2),
        ("0.0031825", "0.1273", 4),
        ("0.0002546", "0.1273", 4),
        ("0.0000001", "1.00", 7),
        ("0.000000001", "1.00", 8),
        ("5", "100.00", 2),
    ],
    ids=[
        "cent-exact-entry-coarse-grid",
        "large-price-coarse-grid",
        "sub-cent-entry-needs-four",
        "sub-cent-entry-finest-grid",
        "fine-grid-widens-past-the-quote",
        "grid-finer-than-eight-is-capped",
        "step-wider-than-a-dollar-stays-at-cents",
    ],
)
def test_price_places_is_the_finest_of_the_quote_and_the_grid(
    step: str, entry: str, expected: int
) -> None:
    places = figures.price_places(step=Decimal(step), entry=Decimal(entry))

    assert places == expected


@pytest.mark.parametrize(
    "entry", ["152.40", "0.1273", "4.2150"], ids=["cents", "link", "link"]
)
def test_a_coarse_grid_quotes_the_entry_exactly_as_price_display_would(
    entry: str,
) -> None:
    """The rule widens ``price_display``; on a coarse grid it *is* it."""
    curve = make_curve(entry=entry)
    places = figures.price_places(step=curve.price_step, entry=curve.entry_price)

    rendered = figures.price(curve.entry_price, shape(places)).display

    assert rendered == price_display(curve.entry_price)


def test_no_two_points_of_the_finest_curve_share_a_displayed_price() -> None:
    """51 rows on the cheapest seeded ticker still read as 51 prices."""
    curve = make_curve(entry="0.1273", range_pct=5, steps=25)
    places = figures.price_places(step=curve.price_step, entry=curve.entry_price)

    labels = [point.label for point in figures.line(curve, shape(places)).points]

    assert len(labels) == 51
    assert len(set(labels)) == 51


def test_the_totals_name_the_entry_the_break_even_and_the_notional() -> None:
    curve = make_curve(entry="152.40")

    rows = figures.totals(curve, shape(2))

    assert [row.label for row in rows] == [
        "Entry price",
        "Break-even price",
        "Notional",
    ]
    assert [row.amount.display for row in rows] == ["$152.40", "$152.40", "$1,524.00"]


def test_the_line_pairs_each_grid_price_with_what_is_made_there() -> None:
    curve = make_curve(entry="152.40", range_pct=30, steps=1)

    series = figures.line(curve, shape(2))

    assert series.name == figures.SERIES_NAME
    assert [(p.label, p.value.display) for p in series.points] == [
        ("$106.68", "-$457.20"),
        ("$152.40", "$0.00"),
        ("$198.12", "$457.20"),
    ]


def test_the_markers_carry_the_entry_the_break_even_and_both_ends() -> None:
    curve = make_curve(entry="152.40", range_pct=30, steps=1)

    marks = figures.notes(curve, shape(2))

    assert [(note.label, note.text) for note in marks] == [
        ("Entry", "$152.40"),
        ("Break-even", "$152.40"),
        ("Low", "at $106.68: -$457.20"),
        ("High", "at $198.12: $457.20"),
    ]


def test_the_requested_precision_governs_money_but_never_a_unit_price() -> None:
    """`precision` is the caller's; the price resolution is the grid's."""
    curve = make_curve(entry="0.1273")
    fine = shape(4, precision=0)

    rows = figures.totals(curve, fine)

    assert rows[0].amount.display == "$0.1273"
    assert rows[2].amount.display == "$1"
