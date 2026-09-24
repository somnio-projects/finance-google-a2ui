"""Spec 0031 — the sector's weight before and after the order.

The ratios are asserted against the design portfolio's own totals (spec 0025
§4): Technology holds $224,903.40 of $482,915.20, and the design's three legs
add $9,427.78 to it.
"""

from decimal import Decimal

from app.domain.draft_impact import price_legs
from app.domain.draft_legs import parse_legs
from app.domain.draft_weights import group_of, weight_shifts
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from tests.unit.domain.conftest import make_portfolio

TOTAL = Decimal("482915.20")
TECHNOLOGY = Decimal("224903.40")
DESIGN_LEGS = price_legs(parse_legs("NVDA:3,AVGO:2,AMD:14"))


def test_an_equity_is_grouped_by_sector_and_a_fund_by_asset_class() -> None:
    """OD-5 — no leg is left out of the panel for lacking a sector."""
    assert group_of(market_asset("NVDA")) == ("technology", "Technology")
    assert group_of(market_asset("BND")) == ("bonds", "Bonds")
    assert group_of(market_asset("USD")) == ("cash", "Cash")


def test_a_buy_moves_the_sector_up_by_the_order_over_the_whole(
    portfolio: Portfolio,
) -> None:
    """AC-5 — the denominator is the portfolio on both sides."""
    (shift,) = weight_shifts(portfolio, DESIGN_LEGS, "buy")

    assert (shift.key, shift.label) == ("technology", "Technology")
    assert shift.before == TECHNOLOGY / TOTAL
    assert shift.after == (TECHNOLOGY + Decimal("9427.78")) / TOTAL


def test_a_sell_moves_it_down_by_the_same_amount(portfolio: Portfolio) -> None:
    (shift,) = weight_shifts(portfolio, DESIGN_LEGS, "sell")

    assert shift.after == (TECHNOLOGY - Decimal("9427.78")) / TOTAL


def test_groups_arrive_in_first_leg_order_and_sum_their_legs(
    portfolio: Portfolio,
) -> None:
    """Two bond funds are one row; the gold ETF is another, after it."""
    legs = price_legs(parse_legs("BND:10,GLD:1,AGG:10"))
    shifts = weight_shifts(portfolio, legs, "buy")

    assert [shift.label for shift in shifts] == ["Bonds", "Alternatives"]
    bonds = shifts[0]
    # The seeded Bonds class is $86,925.00 (spec 0025 §4); the two legs add
    # 10 x $71.40 and 10 x $97.50 to it.
    assert bonds.before == Decimal("86925.00") / TOTAL
    assert bonds.after == Decimal("88614.00") / TOTAL


def test_an_empty_portfolio_reports_zeros_rather_than_dividing_by_them() -> None:
    (shift,) = weight_shifts(make_portfolio(), DESIGN_LEGS, "buy")

    assert (shift.before, shift.after) == (ZERO, ZERO)
