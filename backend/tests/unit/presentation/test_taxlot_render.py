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
        ("75", [1, 1], ["+$3,669.90", "+$26,679.60"]),
        ("60", [0, 1], ["$0.00", "+$26,679.60"]),
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
    assert row.proceeds.display == "$72,279.60"
    assert row.proceeds.amount == Decimal("72279.600000")  # exact, unrounded
    assert row.cost_basis.amount == Decimal("45600.00")


def test_a_gain_and_a_loss_are_signed(portfolio: Portfolio) -> None:
    """PYPL is the seeded loser, so the sign is not decoration (AC-4)."""
    gain = render(portfolio, TaxLotsTableOptions())
    loss = render(portfolio, TaxLotsTableOptions(symbol="PYPL", quantity="250"))
    assert gain.lots[0].gain_loss.display == "+$26,679.60"
    assert gain.lots[0].trend == "up"
    assert loss.lots[0].gain_loss.display == "-$5,825.00"
    assert loss.lots[0].trend == "down"


def test_precision_governs_the_realised_figures(portfolio: Portfolio) -> None:
    """`precision` rounds what the table totals (OD-5's surviving half).

    The unit price it used to be contrasted against left the payload with the
    `price` total in spec 0024 §7 — no component bound it. The tool still
    quotes a sub-cent price, and `test_sale_rows.py` is where that is asserted
    now.
    """
    xom = TaxLotsTableOptions(symbol="XOM", quantity="100")
    assert render(portfolio, xom).proceeds.amount.display == "$3,422.00"
    coarse = xom.model_copy(update={"precision": 0})
    assert render(portfolio, coarse).proceeds.amount.display == "$3,422"


def test_units_arrive_as_a_pair_and_the_printable_half_is_trimmed(
    portfolio: Portfolio,
) -> None:
    """AC-2 — the Shares column binds `units_display`, never `units`."""
    payload = render(portfolio, TaxLotsTableOptions(quantity="0.12345678"))
    assert payload.lots[0].units == Decimal("0.12345678")
    assert payload.lots[0].units_display == "0.12345678"


def test_the_acquisition_date_arrives_written_out(portfolio: Portfolio) -> None:
    """AC-1 — no ISO date reaches a widget, and the locale reaches the date."""
    payload = render(portfolio, TaxLotsTableOptions())
    row = payload.lots[0]
    assert row.acquired_on_display == f"{row.acquired_on:%m/%d/%Y}"
    german = render(portfolio, TaxLotsTableOptions(locale="de-DE"))
    assert german.lots[0].acquired_on_display == f"{row.acquired_on:%d.%m.%Y}"


def test_render_honours_the_locale(portfolio: Portfolio) -> None:
    payload = render(portfolio, TaxLotsTableOptions(locale="es-AR"))
    assert payload.proceeds.amount.display == "US$ 90.349,50"
    assert payload.by_term[1].realized.display == "+US$ 26.679,60"


def test_surface_maps_the_payload_onto_the_table(portfolio: Portfolio) -> None:
    rendered = surface(render(portfolio, TaxLotsTableOptions()))
    assert rendered.component == "TaxLotTable"
    assert rendered.view == VIEW_ID
    assert [total["label"] for total in rendered.props["totals"]] == [
        "Proceeds",
        "Cost basis",
        "Realised P/L",
    ]
    assert [half["term"] for half in rendered.props["byTerm"]] == ["short", "long"]
    assert rendered.props["rows"][0]["label"] == "lot-nvda-01"
    assert "remaining" not in rendered.props
    assert rendered.props["subtitle"] == "Sell 75 NVDA under FIFO"


def test_the_view_id_is_reachable_by_every_caller() -> None:
    """The id pattern the three callers share rejected this id before (AC-11)."""
    assert ViewQuery(view=[VIEW_ID]).view == [VIEW_ID]
    assert RenderIntent(view=VIEW_ID).view == VIEW_ID
    assert ViewRenderRequest(view=VIEW_ID).view == VIEW_ID
