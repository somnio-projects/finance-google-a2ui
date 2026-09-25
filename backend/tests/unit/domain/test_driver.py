"""Spec 0032 — what one holding did today, computed once for card and tool."""

from decimal import Decimal

import pytest

from app.domain.day_change import day_change, portfolio_previous_value
from app.domain.driver import driver_detail
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from tests.conftest import FROZEN_NOW
from tests.unit.domain.conftest import make_holding


@pytest.fixture
def portfolio() -> Portfolio:
    return seed_portfolio(as_of=FROZEN_NOW)


@pytest.fixture
def cash_only() -> Portfolio:
    """A portfolio that is all settlement fund: today it moved by nothing."""
    cash = make_holding(
        symbol="USDC", quantity="100", price="1", market_value="100", cost_basis="100"
    )
    return Portfolio(as_of=FROZEN_NOW, positions=(cash,), lots=(), ledger=())


def test_the_top_contributor_is_the_seeds_largest_day_gain(
    portfolio: Portfolio,
) -> None:
    """The design drills into BTC; the seed agrees it led the day."""
    detail = driver_detail(portfolio, "BTC")

    assert detail is not None
    assert (detail.standing, detail.rank) == ("top_contributor", 1)
    assert detail.contribution == Decimal("4767.00")
    assert detail.price_change == Decimal("2270.00")
    assert detail.quantity == Decimal("2.10")
    assert detail.price == Decimal("64250.00")


def test_the_share_is_the_contribution_over_the_portfolios_day(
    portfolio: Portfolio,
) -> None:
    """Above one here: AAVE moved the other way, so BTC out-gained the day."""
    detail = driver_detail(portfolio, "BTC")
    holdings = portfolio.holdings()
    gain = portfolio.total_market_value() - portfolio_previous_value(holdings)

    assert detail is not None
    assert detail.day_gain == gain == Decimal("2201.05")
    assert detail.share == detail.contribution / gain
    assert detail.share > 1


@pytest.mark.parametrize(
    ("symbol", "standing", "rank"),
    [
        ("BTC", "top_contributor", 1),
        ("ETH", "contributor", 2),
        ("AAVE", "top_detractor", 1),
        ("SOL", "detractor", 2),
        ("USDC", "unchanged", 1),
    ],
    ids=["top-contributor", "second-contributor", "top-detractor", "detractor", "flat"],
)
def test_every_standing_is_reachable_from_the_seed(
    portfolio: Portfolio, symbol: str, standing: str, rank: int
) -> None:
    detail = driver_detail(portfolio, symbol)

    assert detail is not None
    assert (detail.standing, detail.rank) == (standing, rank)


def test_rank_counts_only_the_holdings_on_the_same_side(
    portfolio: Portfolio,
) -> None:
    """A detractor's rank is among detractors, not among every holding."""
    detail = driver_detail(portfolio, "LINK")
    losers = [row for row in portfolio.holdings() if day_change(row) < 0]
    losers.sort(key=lambda row: (-abs(day_change(row)), row.symbol))

    assert detail is not None
    assert [row.symbol for row in losers][detail.rank - 1] == "LINK"


def test_the_symbol_is_normalised_before_the_lookup(portfolio: Portfolio) -> None:
    detail = driver_detail(portfolio, " btc ")

    assert detail is not None
    assert detail.symbol == "BTC"


def test_a_symbol_the_portfolio_does_not_hold_is_none_not_an_error(
    portfolio: Portfolio,
) -> None:
    """AVAX is in the market reference and not in the portfolio: the leaf."""
    assert driver_detail(portfolio, "AVAX") is None


def test_a_flat_day_has_no_share_to_report(cash_only: Portfolio) -> None:
    """Zero over zero is not a ratio, so the share is zero (spec 0026's rule)."""
    detail = driver_detail(cash_only, "USDC")

    assert detail is not None
    assert detail.share == Decimal(0)
    assert detail.standing == "unchanged"
