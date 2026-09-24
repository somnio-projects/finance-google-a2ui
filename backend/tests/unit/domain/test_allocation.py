"""Spec 0026 OD-2 — the groupings the donut can be sliced by, as literals.

The class subtotals are the design's own figures (`Catalog_HoldingsSummary`,
`Home.dc.html`), asserted as literals rather than re-derived from the seed:
a derivation check proves only that arithmetic is arithmetic.
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
    assert [g.label for g in groups] == ["Equities", "Bonds", "Cash", "Alternatives"]
    assert [g.value for g in groups] == [
        Decimal("299407.00"),
        Decimal("86925.00"),
        Decimal("38633.22"),
        Decimal("57949.98"),
    ]


def test_class_weights_sum_to_one_and_counts_to_every_holding(
    portfolio: Portfolio,
) -> None:
    groups = by_asset_class(portfolio.holdings())
    assert sum((g.weight for g in groups), ZERO) == Decimal(1)
    assert sum(g.count for g in groups) == len(portfolio.holdings())


def test_class_previous_values_give_the_day_changes_the_home_page_draws(
    portfolio: Portfolio,
) -> None:
    """+0.9 % · -0.2 % · 0.0 % · +1.4 %, rounded as the legend prints them."""
    ratios = [
        round((g.value - g.previous_value) / g.previous_value * 100, 1)
        for g in by_asset_class(portfolio.holdings())
    ]
    assert ratios == [Decimal("0.9"), Decimal("-0.2"), Decimal("0.0"), Decimal("1.4")]


def test_sectors_fold_the_equities_only_in_the_design_order(
    portfolio: Portfolio,
) -> None:
    groups = by_sector(portfolio.holdings())
    assert [g.key for g in groups] == list(SECTOR_ORDER)
    assert sum((g.value for g in groups), ZERO) == Decimal("299407.00")
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
