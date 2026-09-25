"""Spec 0031, re-based by 0044 — the group's weight before and after the order.

The ratios are asserted against the seeded portfolio's own totals: Bitcoin
holds $134,925.00 and Ethereum $239,000.00 of $482,915.20, and the design's
three legs add $3,855.00, $3,480.00 and $2,438.40 to three *different* groups.

That is the shape spec 0044 OD-2 bought: the equities panel folded all three
legs into Technology, while BTC, ETH and SOL settle on three chains, so the
panel now has three rows. A group that folds more than one leg is still
covered — LINK and ARB are both Ethereum.
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
BITCOIN = Decimal("134925.00")
ETHEREUM = Decimal("239000.00")
SOLANA = Decimal("57226.20")
DESIGN_LEGS = price_legs(parse_legs("BTC:0.06,ETH:1.0,SOL:16"))


def test_an_asset_is_grouped_by_ecosystem_and_the_stablecoin_by_class() -> None:
    """OD-5 — no leg is left out of the panel for lacking an ecosystem."""
    assert group_of(market_asset("BTC")) == ("bitcoin", "Bitcoin")
    assert group_of(market_asset("LINK")) == ("ethereum", "Ethereum")
    assert group_of(market_asset("USDC")) == ("stablecoin", "Stablecoins")


def test_a_buy_moves_each_group_up_by_its_legs_over_the_whole(
    portfolio: Portfolio,
) -> None:
    """AC-5 — the denominator is the portfolio on both sides."""
    shifts = weight_shifts(portfolio, DESIGN_LEGS, "buy")

    assert [(s.key, s.label) for s in shifts] == [
        ("bitcoin", "Bitcoin"),
        ("ethereum", "Ethereum"),
        ("solana", "Solana"),
    ]
    assert shifts[0].before == BITCOIN / TOTAL
    assert shifts[0].after == (BITCOIN + Decimal("3855.00")) / TOTAL
    assert shifts[1].after == (ETHEREUM + Decimal("3480.00")) / TOTAL
    assert shifts[2].after == (SOLANA + Decimal("2438.40")) / TOTAL


def test_a_sell_moves_it_down_by_the_same_amount(portfolio: Portfolio) -> None:
    shifts = weight_shifts(portfolio, DESIGN_LEGS, "sell")

    assert shifts[0].after == (BITCOIN - Decimal("3855.00")) / TOTAL


def test_groups_arrive_in_first_leg_order_and_sum_their_legs(
    portfolio: Portfolio,
) -> None:
    """LINK and ARB are one Ethereum row; Bitcoin is another, after it."""
    legs = price_legs(parse_legs("LINK:10,BTC:0.01,ARB:100"))
    shifts = weight_shifts(portfolio, legs, "buy")

    assert [shift.label for shift in shifts] == ["Ethereum", "Bitcoin"]
    ethereum = shifts[0]
    # The two Ethereum legs add 10 x $22.60 and 100 x $0.8640 to $239,000.00.
    assert ethereum.before == ETHEREUM / TOTAL
    assert ethereum.after == Decimal("239312.40") / TOTAL


def test_an_empty_portfolio_reports_zeros_rather_than_dividing_by_them() -> None:
    shifts = weight_shifts(make_portfolio(), DESIGN_LEGS, "buy")

    assert all((shift.before, shift.after) == (ZERO, ZERO) for shift in shifts)
