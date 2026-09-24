"""Spec 0026 — what moved since yesterday, computed once for every consumer."""

from decimal import Decimal

from app.domain.day_change import (
    MOVERS,
    change_ratio,
    day_change,
    portfolio_previous_value,
    previous_value,
    top_movers,
    trend_of,
)
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio


def test_previous_value_is_quantity_times_the_reference_previous_close(
    portfolio: Portfolio,
) -> None:
    nvda = next(row for row in portfolio.holdings() if row.symbol == "NVDA")
    assert previous_value(nvda) == nvda.quantity * market_asset("NVDA").previous_close
    assert previous_value(nvda) == Decimal("104049.00")


def test_day_change_is_signed_and_reconciles_with_the_two_prices(
    portfolio: Portfolio,
) -> None:
    by_symbol = {row.symbol: row for row in portfolio.holdings()}
    assert day_change(by_symbol["NVDA"]) > ZERO
    assert day_change(by_symbol["MSFT"]) < ZERO
    assert day_change(by_symbol["USD"]) == ZERO


def test_change_ratio_is_zero_from_a_zero_base() -> None:
    assert change_ratio(Decimal(10), ZERO) == ZERO
    assert change_ratio(Decimal("101"), Decimal("100")) == Decimal("0.01")


def test_trend_names_the_direction_without_arithmetic_downstream() -> None:
    assert trend_of(Decimal("0.01")) == "up"
    assert trend_of(Decimal("-0.01")) == "down"
    assert trend_of(ZERO) == "flat"


def test_the_portfolio_moved_by_the_figure_the_home_page_states(
    portfolio: Portfolio,
) -> None:
    """`Home.dc.html`: ▲ +$3,240.18 (+0.68%) today — solved into the seed."""
    previous = portfolio_previous_value(portfolio.holdings())
    assert portfolio.total_market_value() - previous == Decimal("3240.18")


def test_top_movers_are_the_three_single_names_the_design_lists() -> None:
    """NVDA ▲ +4.2%, TSLA ▼ -2.3%, AAPL ▲ +1.1% — funds and cash never appear."""
    rows = top_movers()
    assert len(rows) == MOVERS
    assert [row.symbol for row in rows] == ["NVDA", "TSLA", "AAPL"]
    assert [row.ratio > ZERO for row in rows] == [True, False, True]
    assert all(not market_asset(row.symbol).is_fund for row in rows)


def test_top_movers_are_ordered_by_the_size_of_the_move() -> None:
    magnitudes = [abs(row.ratio) for row in top_movers(limit=8)]
    assert magnitudes == sorted(magnitudes, reverse=True)
    assert "USD" not in {row.symbol for row in top_movers(limit=20)}
    assert "GLD" not in {row.symbol for row in top_movers(limit=20)}
