"""GGU-36 — window attribution: the waterfall must close, and stay deterministic."""

from datetime import timedelta
from decimal import Decimal

import pytest

from app.domain.attribution import attribute_window
from app.domain.errors import WindowOutOfRangeError
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio

WINDOW = timedelta(days=7)


def test_contributions_sum_exactly_to_the_portfolio_change(
    portfolio: Portfolio,
) -> None:
    """AC-2, and the reason this module exists.

    A waterfall whose bars do not reach its own end bar is worse than no
    chart, so the closure is asserted exactly rather than within an epsilon.
    """
    result = attribute_window(portfolio, window=WINDOW)

    assert result.closes()
    bars = sum((row.contribution for row in result.contributions), ZERO)

    assert bars == result.change


def test_the_change_is_the_difference_between_the_two_totals(
    portfolio: Portfolio,
) -> None:
    result = attribute_window(portfolio, window=WINDOW)

    assert result.change == result.end_value - result.start_value


def test_every_contribution_is_its_own_start_to_end_move(portfolio: Portfolio) -> None:
    result = attribute_window(portfolio, window=WINDOW)

    assert all(
        row.contribution == row.end_value - row.start_value
        for row in result.contributions
    )


def test_contributions_are_ordered_by_absolute_size_descending(
    portfolio: Portfolio,
) -> None:
    """AC-6 — the waterfall reads top-down, biggest mover first."""
    result = attribute_window(portfolio, window=WINDOW)

    sizes = [abs(row.contribution) for row in result.contributions]
    assert sizes == sorted(sizes, reverse=True)


def test_the_same_portfolio_and_window_attribute_identically(
    portfolio: Portfolio,
) -> None:
    """AC-4 — nothing here reads a clock, so two calls cannot differ."""
    assert attribute_window(portfolio, window=WINDOW) == attribute_window(
        portfolio, window=WINDOW
    )


@pytest.mark.parametrize("days", [1, 7, 30], ids=["one_day", "one_week", "one_month"])
def test_every_supported_window_closes(portfolio: Portfolio, days: int) -> None:
    """AC-5 — each window the tool offers produces a closed waterfall."""
    result = attribute_window(portfolio, window=timedelta(days=days))

    assert result.days == days
    assert result.closes()


def test_a_zero_window_reports_no_movement_rather_than_failing(
    portfolio: Portfolio,
) -> None:
    result = attribute_window(portfolio, window=timedelta(0))

    assert result.change == ZERO
    assert result.change_ratio == ZERO
    assert result.closes()
    assert all(row.share == ZERO for row in result.contributions)


def test_a_negative_window_is_a_programming_error(portfolio: Portfolio) -> None:
    with pytest.raises(WindowOutOfRangeError, match="must not be negative"):
        attribute_window(portfolio, window=timedelta(days=-1))


def test_a_symbol_filter_attributes_only_those_holdings(portfolio: Portfolio) -> None:
    """AC-5 — and the filtered waterfall still closes against its own total."""
    result = attribute_window(portfolio, window=WINDOW, symbols=frozenset({"BTC"}))

    assert [row.symbol for row in result.contributions] == ["BTC"]
    assert result.closes()
    assert result.end_value == next(
        row.market_value for row in portfolio.holdings() if row.symbol == "BTC"
    )


def test_a_filter_matching_nothing_yields_an_empty_flat_attribution(
    portfolio: Portfolio,
) -> None:
    result = attribute_window(portfolio, window=WINDOW, symbols=frozenset({"NOPE"}))

    assert result.contributions == ()
    assert result.start_value == ZERO
    assert result.change == ZERO
    assert result.change_ratio == ZERO
    assert result.closes()


def test_shares_sum_to_one_but_only_to_decimal_precision(
    portfolio: Portfolio,
) -> None:
    """The money closes exactly; the ratios cannot, and that is not a bug.

    ``contribution`` is a subtraction of two exact amounts, so the bars reach
    the end bar exactly. ``share`` is a division, and division is not exact in
    any finite base — the shares land one unit in the last place away from 1.
    The chart is therefore drawn from the contributions, never from the
    shares, and this test pins the distinction so nobody later "fixes" the
    closure by rescaling the ratios.
    """
    result = attribute_window(portfolio, window=WINDOW)
    assert result.change != ZERO, "the seed must move over a week for this to mean much"

    total_share = sum((row.share for row in result.contributions), ZERO)

    assert abs(total_share - Decimal(1)) < Decimal("1e-24")


def test_the_end_value_is_the_portfolio_total_when_nothing_is_filtered(
    portfolio: Portfolio,
) -> None:
    result = attribute_window(portfolio, window=WINDOW)

    assert result.end_value == portfolio.total_market_value()
