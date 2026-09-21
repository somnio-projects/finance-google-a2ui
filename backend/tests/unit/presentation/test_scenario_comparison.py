"""Spec 0017 AC-2..AC-6, AC-8, AC-10 — what the comparison card shows.

Every number asserted here is a literal: the render is pure and the portfolio
is seeded at a frozen ``as_of``, so a changed string is a changed contract, not
a changed calendar. The seeded NVDA position is the one that makes the card
worth building — its two lots straddle the 1-year boundary *and* disagree on
unit cost, so FIFO lands somewhere LIFO and HIFO do not.
"""

from decimal import Decimal

import pytest

from app.domain.lot_selection import LotMethod
from app.domain.portfolio import Portfolio
from app.presentation.scenario_options import ScenarioComparisonOptions
from app.presentation.views.scenario_comparison import (
    VIEW_ID,
    ScenarioComparisonPayload,
    render,
)

#: The default scenario: 30 NVDA, the size of the position's newer, dearer lot.
EXPECTED: dict[LotMethod, tuple[str, str, str, str, str]] = {
    # method: (lot id, cost basis, realised, short-term, long-term)
    LotMethod.FIFO: (
        "lot-nvda-01",
        "$22,800.00",
        "+$13,339.80",
        "$0.00",
        "+$13,339.80",
    ),
    LotMethod.LIFO: (
        "lot-nvda-02",
        "$28,800.00",
        "+$7,339.80",
        "+$7,339.80",
        "$0.00",
    ),
    LotMethod.HIFO: (
        "lot-nvda-02",
        "$28,800.00",
        "+$7,339.80",
        "+$7,339.80",
        "$0.00",
    ),
}


@pytest.fixture
def card(portfolio: Portfolio) -> ScenarioComparisonPayload:
    """The card the defaults render over the seeded portfolio."""
    return render(portfolio, ScenarioComparisonOptions())


def test_the_defaults_resolve_to_the_largest_position_and_its_smallest_lot(
    card: ScenarioComparisonPayload,
) -> None:
    assert card.view == VIEW_ID
    assert card.subject.symbol == "NVDA"
    assert card.subject.label == "NVIDIA Corp"
    assert card.subject.quantity_display == "30"
    assert [column.method for column in card.columns] == list(LotMethod)


def test_every_column_is_costed_against_the_same_units_price_and_proceeds(
    portfolio: Portfolio, card: ScenarioComparisonPayload
) -> None:
    assert card.subject.price.display == "$1,204.66"
    assert card.subject.proceeds.display == "$36,139.80"
    pair = render(
        portfolio,
        ScenarioComparisonOptions(methods=(LotMethod.HIFO, LotMethod.FIFO)),
    )
    assert pair.subject == card.subject, "the shared header cannot vary per column"


@pytest.mark.parametrize("method", list(LotMethod), ids=[m.value for m in LotMethod])
def test_each_method_consumes_the_lot_it_names(
    card: ScenarioComparisonPayload, method: LotMethod
) -> None:
    column = next(row for row in card.columns if row.method is method)
    lot, basis, realised, short, long = EXPECTED[method]
    assert column.lots == (lot,)
    assert column.cost_basis.display == basis
    assert column.realized_pl.display == realised
    assert column.short_term_pl.display == short
    assert column.long_term_pl.display == long


def test_each_column_adds_up(card: ScenarioComparisonPayload) -> None:
    proceeds = card.subject.proceeds.amount
    for column in card.columns:
        assert column.cost_basis.amount + column.realized_pl.amount == proceeds
        assert (
            column.short_term_pl.amount + column.long_term_pl.amount
            == column.realized_pl.amount
        )
        assert column.short_term_lots + column.long_term_lots == len(column.lots)


def test_the_card_recommends_nothing(card: ScenarioComparisonPayload) -> None:
    keys = set(ScenarioComparisonPayload.model_fields)
    for column in card.columns:
        keys |= set(type(column).model_fields)
    keys |= set(type(card.spread).model_fields)
    assert not keys & {"recommended", "best", "rank", "score", "winner"}
    assert card.notes[-1].text.startswith("No method is recommended")
    assert card.spread.differs is True
    assert card.spread.amount.display == "$6,000.00"
    assert card.spread.highest is LotMethod.FIFO
    assert card.spread.lowest is LotMethod.LIFO


def test_columns_keep_the_requested_order_and_are_never_sorted_by_outcome(
    portfolio: Portfolio,
) -> None:
    asked = (LotMethod.HIFO, LotMethod.FIFO)
    card = render(portfolio, ScenarioComparisonOptions(methods=asked))
    assert tuple(column.method for column in card.columns) == asked


def test_a_sale_that_closes_the_position_reports_no_difference(
    portfolio: Portfolio,
) -> None:
    card = render(portfolio, ScenarioComparisonOptions(quantity=Decimal(90)))
    assert card.spread.differs is False
    assert card.spread.amount.display == "$0.00"
    assert card.spread.highest is None
    assert card.spread.lowest is None
    assert card.notes[-1].label == "No difference"


def test_the_unit_price_is_quoted_at_price_precision(portfolio: Portfolio) -> None:
    card = render(portfolio, ScenarioComparisonOptions(symbol="xom"))
    assert card.subject.symbol == "XOM"
    assert card.subject.price.display == "$34.22"
    assert card.subject.proceeds.display == "$4,448.60"
