"""Spec 0017 AC-7, AC-9 — what the comparison card turns down.

A card that puts figures side by side claims they are the same kind of thing,
so most of this file is about the claims it refuses to make: two symbols, two
sale sizes, two identical columns, or a sale the position cannot cover.
"""

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.core.errors import ValidationFailedError
from app.domain.errors import PositionTooSmallError
from app.domain.lot_selection import LotMethod
from app.domain.portfolio import Portfolio
from app.presentation.registry import Projection
from app.presentation.resolve import validated_options
from app.presentation.scenario_options import (
    MAX_SCENARIOS,
    ScenarioComparisonOptions,
)
from app.presentation.views.scenario_comparison import PROJECTION, render

ALL_METHODS = tuple(LotMethod)


def test_a_card_cannot_be_asked_to_compare_two_symbols_or_two_sizes() -> None:
    """The refusal is structural: there is no option that could express it."""
    fields = ScenarioComparisonOptions.model_fields
    assert fields["symbol"].annotation is not tuple
    assert fields["quantity"].annotation is not tuple
    with pytest.raises(ValidationError, match="symbol"):
        ScenarioComparisonOptions(symbol=["BTC", "ETH"])  # type: ignore[arg-type]
    with pytest.raises(ValidationError, match="quantity"):
        ScenarioComparisonOptions(quantity=["1", "2"])  # type: ignore[arg-type]


@pytest.mark.parametrize(
    ("options", "expected"),
    [
        ({"top_n": 3}, "top_n"),
        ({"precision": 99}, "precision"),
        ({"symbol": "b$c"}, "symbol"),
        ({"quantity": "0"}, "quantity"),
        ({"quantity": "-1"}, "quantity"),
        ({"methods": ["FIFO", "FIFO"]}, "methods"),
        ({"methods": ["FIFO"]}, "methods"),
        ({"methods": ["FIFO", "LIFO", "HIFO", "FIFO"]}, "methods"),
        ({"methods": ["MIFO", "FIFO"]}, "methods"),
    ],
    ids=[
        "undeclared_option",
        "precision_out_of_range",
        "symbol_not_a_ticker",
        "zero_units",
        "negative_units",
        "repeated_method",
        "one_method_is_not_a_comparison",
        "more_columns_than_methods_exist",
        "unknown_method",
    ],
)
def test_an_undeclared_or_out_of_range_option_is_rejected(
    options: dict[str, object], expected: str
) -> None:
    projection: Projection = PROJECTION
    with pytest.raises(ValidationFailedError, match=expected):
        validated_options(projection, options)


def test_the_cap_is_the_number_of_methods_the_domain_offers() -> None:
    """A fourth column would need a fourth method, not a wider bound."""
    assert MAX_SCENARIOS == len(ALL_METHODS)
    assert ScenarioComparisonOptions(methods=ALL_METHODS).methods == ALL_METHODS


def test_selling_more_than_is_held_is_refused(portfolio: Portfolio) -> None:
    """It fails every column identically, so there is no card (OD-5)."""
    options = ScenarioComparisonOptions(symbol="BTC", quantity=Decimal("5"))
    with pytest.raises(PositionTooSmallError, match="BTC holds fewer units"):
        render(portfolio, options)


def test_the_refusal_names_the_symbol_but_no_quantity(portfolio: Portfolio) -> None:
    options = ScenarioComparisonOptions(symbol="BTC", quantity=Decimal("5"))
    with pytest.raises(PositionTooSmallError) as caught:
        render(portfolio, options)
    assert caught.value.requested == Decimal("5")
    assert caught.value.held == Decimal("2.10000000")
    assert "5" not in str(caught.value)
    assert "2.1" not in str(caught.value)


def test_a_symbol_with_no_open_lots_is_refused(portfolio: Portfolio) -> None:
    """AVAX is in the market reference; the portfolio traded out of it (0044)."""
    with pytest.raises(ValidationFailedError, match="no open tax lots in AVAX"):
        render(portfolio, ScenarioComparisonOptions(symbol="AVAX"))


def test_a_portfolio_with_no_lots_at_all_is_refused(
    empty_portfolio: Portfolio,
) -> None:
    with pytest.raises(ValidationFailedError, match="holds no open tax lots"):
        render(empty_portfolio, ScenarioComparisonOptions())


def test_an_explicit_quantity_and_symbol_skip_both_default_rules(
    portfolio: Portfolio,
) -> None:
    card = render(
        portfolio,
        ScenarioComparisonOptions(symbol=" sol ", quantity=Decimal("10")),
    )
    assert card.subject.symbol == "SOL"
    assert card.subject.quantity_display == "10"
    assert card.spread.differs is False
