"""Spec 0026 OD-3 — one value series for the sparkline and the range delta."""

from datetime import timedelta
from decimal import Decimal

from app.domain.day_change import portfolio_previous_value
from app.domain.history import HISTORY_DAYS
from app.domain.holdings import Holding
from app.domain.portfolio import Portfolio
from app.domain.portfolio_history import value_on, value_series


def test_today_reproduces_the_market_value_exactly(portfolio: Portfolio) -> None:
    assert value_on(portfolio.holdings(), offset=0) == portfolio.total_market_value()


def test_yesterday_is_the_reference_close_so_the_hero_and_series_agree(
    portfolio: Portfolio,
) -> None:
    """The last step of the sparkline is the day change drawn beside it."""
    holdings = portfolio.holdings()
    assert value_on(holdings, offset=1) == portfolio_previous_value(holdings)


def test_the_stablecoin_is_carried_flat_rather_than_drifted(
    portfolio: Portfolio,
) -> None:
    """A dollar-pegged token that wobbled 9 % last Tuesday is a bug (0044)."""
    cash = [row for row in portfolio.holdings() if row.symbol == "USDC"]
    assert value_on(cash, offset=0) == value_on(cash, offset=45)
    assert value_on(cash, offset=45) == Decimal("51764.00")


def test_series_is_ascending_ends_today_and_has_the_points_asked_for(
    portfolio: Portfolio,
) -> None:
    series = value_series(portfolio.holdings(), as_of=portfolio.as_of.date(), points=30)
    assert len(series) == 30
    assert series[-1].observed_on == portfolio.as_of.date()
    assert series[-1].value == portfolio.total_market_value()
    assert series[0].observed_on == portfolio.as_of.date() - timedelta(days=29)
    dates = [point.observed_on for point in series]
    assert dates == sorted(dates)


def test_series_clamps_to_the_history_and_never_fabricates(
    portfolio: Portfolio,
) -> None:
    as_of = portfolio.as_of.date()
    assert (
        len(value_series(portfolio.holdings(), as_of=as_of, points=900)) == HISTORY_DAYS
    )
    assert value_series(portfolio.holdings(), as_of=as_of, points=0) == ()
    assert value_series(portfolio.holdings(), as_of=as_of, points=-3) == ()


def test_a_series_over_no_holdings_is_all_zero(portfolio: Portfolio) -> None:
    empty: list[Holding] = []
    series = value_series(empty, as_of=portfolio.as_of.date(), points=3)
    assert [point.value for point in series] == [Decimal(0)] * 3
