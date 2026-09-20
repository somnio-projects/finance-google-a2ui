"""AC-3/4/10/11 — how the tax-lot table's figures and surface are built.

The split and the formatting are the two things this component can get wrong
in a way a reader cannot detect, so they are asserted directly rather than
through the payload only: a sign, a price precision and a missing half of the
split all look like plausible tables.
"""

from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.domain.terms import LotTerm
from app.presentation.views.taxlots_table import (
    VIEW_ID,
    TaxLotsTableOptions,
    render,
    surface,
)
from app.schemas.render_intent import RenderIntent
from app.schemas.view_renders import ViewRenderRequest
from app.schemas.views import ViewQuery


@pytest.mark.parametrize(
    ("quantity", "lots", "displays"),
    [
        ("0.5", [1, 1], ["+$580.00", "+$8,925.00"]),
        ("0.4", [0, 1], ["$0.00", "+$8,500.00"]),
    ],
    ids=["both-terms", "long-only"],
)
def test_the_term_split_has_one_entry_per_term(
    portfolio: Portfolio, quantity: str, lots: list[int], displays: list[str]
) -> None:
    """A term the sale never touched still renders, at zero (AC-3)."""
    payload = render(portfolio, TaxLotsTableOptions(quantity=quantity))
    assert [half.term for half in payload.by_term] == [LotTerm.SHORT, LotTerm.LONG]
    assert [half.label for half in payload.by_term] == ["Short-term", "Long-term"]
    assert [half.lots for half in payload.by_term] == lots
    assert [half.realized.display for half in payload.by_term] == displays


def test_the_term_split_sums_to_the_realized_total(portfolio: Portfolio) -> None:
    """The halves add up exactly, so the split cannot contradict the table."""
    payload = render(portfolio, TaxLotsTableOptions())
    halves = sum(half.realized.amount for half in payload.by_term)
    assert halves == payload.realized.amount.amount
    assert halves == sum(row.gain_loss.amount for row in payload.lots)


def test_money_is_paired_with_its_exact_decimal(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions())
    row = payload.lots[0]
    assert row.proceeds.display == "$26,985.00"
    assert row.proceeds.amount == Decimal("26985.000000")  # exact, unrounded
    assert row.cost_basis.amount == Decimal("18060.00")


def test_a_gain_and_a_loss_are_signed(portfolio: Portfolio) -> None:
    """LINK is the seeded loser, so the sign is not decoration (AC-4)."""
    gain = render(portfolio, TaxLotsTableOptions())
    loss = render(portfolio, TaxLotsTableOptions(symbol="LINK", quantity="250"))
    assert gain.lots[0].gain_loss.display == "+$8,925.00"
    assert gain.lots[0].trend == "up"
    assert loss.lots[0].gain_loss.display == "-$662.50"
    assert loss.lots[0].trend == "down"


def test_a_sub_cent_price_keeps_four_decimals(portfolio: Portfolio) -> None:
    """`$0.13 x 12,000` would miss the proceeds beside it (spec 0013 OD-4)."""
    payload = render(portfolio, TaxLotsTableOptions(symbol="DOGE", quantity="5000"))
    assert payload.price.amount.display == "$0.1273"
    assert payload.proceeds.amount.display == "$636.50"


def test_precision_never_rounds_the_unit_price(portfolio: Portfolio) -> None:
    """`precision` governs the results, not the figure they multiply (OD-5)."""
    payload = render(
        portfolio, TaxLotsTableOptions(symbol="DOGE", quantity="5000", precision=0)
    )
    assert payload.price.amount.display == "$0.1273"
    assert payload.proceeds.amount.display == "$636"


def test_units_are_trimmed(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions(quantity="0.12345678"))
    assert payload.lots[0].units == "0.12345678"
    assert payload.remaining[0].text == "0.47654322"


def test_render_honours_the_locale(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions(locale="es-AR"))
    assert payload.proceeds.amount.display == "US$ 32.125,00"
    assert payload.by_term[1].realized.display == "+US$ 8.925,00"


def test_the_remainder_describes_the_position_left_over(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions())
    assert [(note.label, note.text) for note in payload.remaining] == [
        ("Units left", "0.1"),
        ("Cost basis", "$5,700.00"),
        ("Market value", "$6,425.00"),
        ("Open lots", "1"),
    ]


def test_surface_maps_the_payload_onto_the_table(portfolio: Portfolio) -> None:
    rendered = surface(render(portfolio, TaxLotsTableOptions()))
    assert rendered.component == "TaxLotTable"
    assert rendered.view == VIEW_ID
    assert [total["label"] for total in rendered.props["totals"]] == [
        "Price",
        "Proceeds",
        "Cost basis",
        "Realised P/L",
    ]
    assert [half["term"] for half in rendered.props["byTerm"]] == ["short", "long"]
    assert rendered.props["rows"][0]["label"] == "lot-btc-01"
    assert rendered.props["remaining"][0]["text"] == "0.1"
    assert rendered.props["subtitle"] == "Sell 0.5 BTC under FIFO"


def test_the_view_id_is_reachable_by_every_caller() -> None:
    """The id pattern the three callers share rejected this id before (AC-11)."""
    assert ViewQuery(view=[VIEW_ID]).view == [VIEW_ID]
    assert RenderIntent(view=VIEW_ID).view == VIEW_ID
    assert ViewRenderRequest(view=VIEW_ID).view == VIEW_ID
