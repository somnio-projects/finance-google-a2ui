"""Spec 0026 — every figure of the Home hero, written down once."""

from datetime import UTC, datetime
from decimal import Decimal

import pytest

from app.domain.history import HISTORY_DAYS
from app.domain.portfolio import Portfolio
from app.presentation import summary_figures as figures
from app.presentation.summary_options import (
    PERIOD_LABELS,
    SPARK_POINTS,
    PortfolioSummaryOptions,
    Range,
    range_offset,
)

DEFAULTS = PortfolioSummaryOptions()


@pytest.mark.parametrize(
    ("hour", "greeting"),
    [
        (6, "Good morning"),
        (11, "Good morning"),
        (12, "Good afternoon"),
        (17, "Good afternoon"),
        (18, "Good evening"),
        (23, "Good evening"),
    ],
)
def test_greeting_follows_the_hour_of_as_of_not_the_clock(
    hour: int, greeting: str
) -> None:
    assert figures.greeting_for(datetime(2026, 9, 18, hour, tzinfo=UTC)) == greeting


def test_today_is_the_home_page_hero_to_the_cent(portfolio: Portfolio) -> None:
    """▲ +$3,240.18 (+0.68%) today."""
    change = figures.change_over(portfolio, portfolio.holdings(), DEFAULTS)
    assert change.amount.display == "+$2,201.05"
    assert change.percent.display == "+0.46%"
    assert change.trend == "up"
    assert change.period == "today"


@pytest.mark.parametrize("selected", ["1w", "1m", "ytd", "1y", "all"])
def test_other_ranges_read_the_history_and_name_their_period(
    portfolio: Portfolio, selected: Range
) -> None:
    options = PortfolioSummaryOptions(range=selected)
    change = figures.change_over(portfolio, portfolio.holdings(), options)
    assert change.period == PERIOD_LABELS[selected]
    assert change.trend == (
        "up"
        if change.amount.amount > 0
        else "down"
        if change.amount.amount < 0
        else "flat"
    )
    assert change.percent.display.endswith("%")


def test_range_offset_clamps_to_the_generated_history() -> None:
    as_of = datetime(2026, 9, 18, tzinfo=UTC).date()
    assert range_offset("1d", as_of=as_of) == 1
    assert range_offset("1w", as_of=as_of) == 7
    assert range_offset("1y", as_of=as_of) == 365
    assert range_offset("all", as_of=as_of) == HISTORY_DAYS - 1
    assert range_offset("ytd", as_of=as_of) == as_of.timetuple().tm_yday - 1
    assert range_offset("ytd", as_of=datetime(2026, 1, 1, tzinfo=UTC).date()) == 1


def test_the_sparkline_is_thirty_days_ending_on_the_total(portfolio: Portfolio) -> None:
    points = figures.spark(portfolio, portfolio.holdings(), DEFAULTS)
    assert len(points) == SPARK_POINTS
    assert points[-1].value.display == "$482,915.20"
    assert points[-1].label == "09/18/2026"
    assert points[0].label == "08/20/2026"


def test_movers_are_written_as_the_design_prints_them() -> None:
    rows = figures.movers(DEFAULTS)
    assert [(r.symbol, r.change.display, r.trend) for r in rows] == [
        ("AVAX", "-6.3%", "down"),
        ("AAVE", "-4.4%", "down"),
        ("BTC", "+3.7%", "up"),
    ]
    assert rows[0].price.display == "$41.80"
    assert rows[0].name == "Avalanche"


def test_signed_helpers_carry_the_exact_value_beside_the_string() -> None:
    money = figures.signed_money(Decimal("-12.5"), options=DEFAULTS)
    assert (money.amount, money.display) == (Decimal("-12.5"), "-$12.50")
    pct = figures.signed_percent(Decimal("0.5"), precision=0, options=DEFAULTS)
    assert (pct.value, pct.display) == (Decimal("0.5"), "+50%")
