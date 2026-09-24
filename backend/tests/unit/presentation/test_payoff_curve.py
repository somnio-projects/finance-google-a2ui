"""Spec 0016 AC-2..AC-5, AC-9 — ``payoff.curve.v1`` over the seeded portfolio.

Rendered at the frozen ``as_of``, so every figure below is a hand-checkable
literal, not whatever the calendar says today.
"""

from decimal import Decimal
from itertools import pairwise

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.payoff_order import PayoffCurveOptions
from app.presentation.views.payoff_curve import (
    DISCLOSURE,
    VIEW_ID,
    PayoffCurvePayload,
    render,
    surface,
)

ENTRY_SOL = "$528.00"


def options(**overrides: object) -> PayoffCurveOptions:
    return PayoffCurveOptions.model_validate(overrides)


def profits(payload: PayoffCurvePayload) -> list[Decimal]:
    return [point.value.amount for point in payload.series[0].points]


def test_the_entry_price_is_a_grid_point_where_nothing_is_made_or_lost(
    portfolio: Portfolio,
) -> None:
    """``steps`` is per side, so the entry is sampled, not interpolated."""
    payload = render(portfolio, options(steps=12))
    points = payload.series[0].points

    assert payload.view == VIEW_ID
    assert payload.title == "Payoff across a price range: buy Vanguard S&P 500 ETF"
    assert len(points) == 25
    assert points[12].label == ENTRY_SOL
    assert points[12].value.amount == Decimal(0)
    assert points[12].value.display == "$0.00"


@pytest.mark.parametrize(
    ("side", "rises"), [("buy", True), ("sell", False)], ids=["buy", "sell"]
)
def test_a_buy_rises_with_the_price_and_a_sell_is_its_mirror(
    portfolio: Portfolio, side: str, rises: bool
) -> None:
    walk = profits(render(portfolio, options(side=side)))
    steps = [later - earlier for earlier, later in pairwise(walk)]

    assert all((step > 0) is rises for step in steps)
    assert walk[0] == -walk[-1]


def test_a_dollar_order_is_sized_at_the_entry_price(portfolio: Portfolio) -> None:
    """The quotient is left unrounded; the figure the reader sees closes."""
    payload = render(portfolio, options(size=750, size_in="usd"))
    notional = payload.totals[2]

    assert notional.amount.display == "$750.00"
    assert notional.amount.amount != Decimal(750)
    assert profits(payload)[0] != Decimal(-225)
    assert profits(payload)[0].quantize(Decimal("0.01")) == Decimal("-225.00")


def test_a_size_in_units_is_priced_as_given(portfolio: Portfolio) -> None:
    payload = render(portfolio, options(symbol="AAPL", size=2, size_in="units"))
    shown = [row.amount.display for row in payload.totals]

    assert shown == ["$233.18", "$233.18", "$466.36"]


def test_the_break_even_is_the_entry_price_for_a_fee_free_order(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, options())

    assert payload.totals[0].amount.display == ENTRY_SOL
    assert payload.totals[1].label == "Break-even price"
    assert payload.totals[1].amount.display == ENTRY_SOL
    assert payload.annotations[1].text == ENTRY_SOL


def test_every_figure_the_client_binds_is_a_preformatted_string(
    portfolio: Portfolio,
) -> None:
    """AC-5 — the client renders strings; the `Decimal` is only for plotting."""
    body = render(portfolio, options()).model_dump(mode="json")
    shown = [row["amount"]["display"] for row in body["totals"]]
    shown += [note["text"] for note in body["annotations"]]
    for point in body["series"][0]["points"]:
        shown += [point["label"], point["value"]["display"]]

    assert len(shown) == 3 + 4 + 2 * 25
    assert all(isinstance(value, str) for value in shown)


def test_the_disclosure_refuses_the_options_reading_of_payoff(
    portfolio: Portfolio,
) -> None:
    """The honesty boundary travels with the chart, not only with the tool."""
    payload = render(portfolio, options())

    assert payload.disclosure == DISCLOSURE
    for missing in ("no strike", "no expiry", "implied volatility", "time decay"):
        assert missing in payload.disclosure


@pytest.mark.parametrize(
    ("selected", "counts"),
    [
        (None, (3, 1, 4)),
        (("series",), (0, 1, 0)),
        (("totals", "annotations"), (3, 0, 4)),
    ],
    ids=["everything", "line-only", "no-line"],
)
def test_a_section_the_widget_does_not_bind_is_not_rendered(
    portfolio: Portfolio,
    selected: tuple[str, ...] | None,
    counts: tuple[int, int, int],
) -> None:
    payload = render(portfolio, options(fields=selected))
    rendered = (len(payload.totals), len(payload.series), len(payload.annotations))

    assert rendered == counts


def test_the_surface_binds_the_line_the_markers_and_the_disclosure(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, options(steps=1))

    drawn = surface(payload)

    assert drawn.component == "RiskPayoffChart"
    assert drawn.view == VIEW_ID
    assert drawn.props["lines"][0]["points"][1]["label"] == ENTRY_SOL
    # `markers` is the keyed block; the labelled sentences it used to hold
    # now travel as `annotations`, which is what they are (spec 0024 §4).
    assert drawn.props["markers"]["break_even"]["at"]["display"] == ENTRY_SOL
    notes = [note["label"] for note in drawn.props["annotations"]]
    assert notes[:2] == ["Entry", "Break-even"]
    assert drawn.props["disclosure"] == DISCLOSURE
