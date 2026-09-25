"""Spec 0026 OD-2, re-based by 0044 — the groupings the donut is sliced by.

The class subtotals are asserted as literals rather than re-derived from the
seed: a derivation check proves only that arithmetic is arithmetic. They add
back to the design's own portfolio total, which spec 0044 OD-4 kept.
"""

from decimal import Decimal

from app.domain.allocation import (
    CLASS_ORDER,
    SECTOR_ORDER,
    by_asset_class,
    by_holding,
    by_sector,
)
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio


def test_asset_classes_come_in_the_design_order_with_its_subtotals(
    portfolio: Portfolio,
) -> None:
    groups = by_asset_class(portfolio.holdings())
    assert [g.key for g in groups] == list(CLASS_ORDER)
    assert [g.label for g in groups] == [
        "Layer 1",
        "Layer 2",
        "Stablecoins",
        "DeFi",
        "Infrastructure",
    ]
    assert [g.value for g in groups] == [
        Decimal("296551.20"),
        Decimal("43740.00"),
        Decimal("51764.00"),
        Decimal("43400.00"),
        Decimal("47460.00"),
    ]
    assert sum((g.value for g in groups), ZERO) == Decimal("482915.20")


def test_class_weights_sum_to_one_and_counts_to_every_holding(
    portfolio: Portfolio,
) -> None:
    groups = by_asset_class(portfolio.holdings())
    assert sum((g.weight for g in groups), ZERO) == Decimal(1)
    assert sum(g.count for g in groups) == len(portfolio.holdings())


def test_class_previous_values_give_the_day_changes_the_home_page_draws(
    portfolio: Portfolio,
) -> None:
    """+1.5 % · +2.6 % · 0.0 % · -4.4 % · -2.4 %, as the legend prints them."""
    ratios = [
        round((g.value - g.previous_value) / g.previous_value * 100, 1)
        for g in by_asset_class(portfolio.holdings())
    ]
    assert ratios == [
        Decimal("1.5"),
        Decimal("2.6"),
        Decimal("0.0"),
        Decimal("-4.4"),
        Decimal("-2.4"),
    ]


def test_ecosystems_fold_only_what_settles_on_one_in_taxonomy_order(
    portfolio: Portfolio,
) -> None:
    """Avalanche is absent because the portfolio traded out of it (0044)."""
    groups = by_sector(portfolio.holdings())
    assert [g.key for g in groups] == [k for k in SECTOR_ORDER if k != "avalanche"]
    # The multi-chain stablecoin has no ecosystem, so this is short of the
    # portfolio total by exactly the USDC balance — that is the point of OD-2.
    assert sum((g.value for g in groups), ZERO) == Decimal("431151.20")
    assert sum((g.weight for g in groups), ZERO) == Decimal(1)


def test_by_holding_is_one_group_per_position_in_portfolio_order(
    portfolio: Portfolio,
) -> None:
    groups = by_holding(portfolio.holdings())
    assert [g.key for g in groups] == [h.symbol for h in portfolio.holdings()]
    assert all(g.count == 1 for g in groups)
    assert [g.value for g in groups] == [h.market_value for h in portfolio.holdings()]


def test_an_empty_portfolio_has_no_groups() -> None:
    assert by_asset_class([]) == ()
    assert by_sector([]) == ()
    assert by_holding([]) == ()
