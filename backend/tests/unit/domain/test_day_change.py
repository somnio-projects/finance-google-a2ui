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
from app.domain.taxonomy import AssetClass


def test_previous_value_is_quantity_times_the_reference_previous_close(
    portfolio: Portfolio,
) -> None:
    btc = next(row for row in portfolio.holdings() if row.symbol == "BTC")
    assert previous_value(btc) == btc.quantity * market_asset("BTC").previous_close
    assert previous_value(btc) == Decimal("130158.00")


def test_day_change_is_signed_and_reconciles_with_the_two_prices(
    portfolio: Portfolio,
) -> None:
    by_symbol = {row.symbol: row for row in portfolio.holdings()}
    assert day_change(by_symbol["BTC"]) > ZERO
    assert day_change(by_symbol["AAVE"]) < ZERO
    assert day_change(by_symbol["USDC"]) == ZERO


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
    """▲ +$2,201.05 (+0.46%) today — solved into the crypto seed (0044 OD-4)."""
    previous = portfolio_previous_value(portfolio.holdings())
    assert portfolio.total_market_value() - previous == Decimal("2201.05")


def test_top_movers_are_the_three_single_names_the_design_lists() -> None:
    """AVAX ▼ -6.3%, AAVE ▼ -4.4%, BTC ▲ +3.7% — the stablecoin never appears."""
    rows = top_movers()
    assert len(rows) == MOVERS
    assert [row.symbol for row in rows] == ["AVAX", "AAVE", "BTC"]
    assert [row.ratio > ZERO for row in rows] == [False, False, True]
    assert all(
        market_asset(row.symbol).asset_class is not AssetClass.STABLECOIN
        for row in rows
    )


def test_top_movers_are_ordered_by_the_size_of_the_move() -> None:
    magnitudes = [abs(row.ratio) for row in top_movers(limit=8)]
    assert magnitudes == sorted(magnitudes, reverse=True)
    assert "USDC" not in {row.symbol for row in top_movers(limit=20)}
