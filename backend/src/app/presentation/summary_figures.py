"""The builders behind ``portfolio.summary.v1`` — each figure written once.

Pure functions from domain facts to ADR-E pairs. The signed displays live
here rather than in ``displays.py`` because a *signed* money is a fact about a
change, not about an amount; nothing else in the catalog prints one.
"""

from datetime import datetime
from decimal import Decimal
from typing import Final

from app.core.dates import date_display
from app.core.signed_display import signed_money_display, signed_percentage_display
from app.domain.day_change import (
    Mover,
    change_ratio,
    portfolio_previous_value,
    top_movers,
    trend_of,
)
from app.domain.holdings import Holding
from app.domain.portfolio import Portfolio
from app.domain.portfolio_history import value_on, value_series
from app.presentation.displays import MoneyDisplay, PercentageDisplay, money
from app.presentation.summary_options import (
    PERIOD_LABELS,
    SPARK_POINTS,
    PortfolioSummaryOptions,
    range_offset,
)
from app.presentation.summary_payload import Change, MoverRow, SparkPoint

#: The design's greetings by hour of ``as_of`` — the clock never read here.
GREETINGS: Final[tuple[tuple[int, str], ...]] = (
    (12, "Good morning"),
    (18, "Good afternoon"),
    (24, "Good evening"),
)
#: A percentage the design prints to one decimal ("+0.9%", "-2.3%").
CHANGE_PERCENT_PRECISION: Final[int] = 1
#: …except the hero, which prints two ("+0.68%").
HERO_PERCENT_PRECISION: Final[int] = 2


def greeting_for(as_of: datetime) -> str:
    """Return the greeting for the hour of ``as_of``, not of the wall clock."""
    return next(word for limit, word in GREETINGS if as_of.hour < limit)


def signed_money(value: Decimal, *, options: PortfolioSummaryOptions) -> MoneyDisplay:
    """Pair a signed amount with its ``+$…`` / ``-$…`` string."""
    return MoneyDisplay(
        amount=value,
        display=signed_money_display(
            value, precision=options.precision, locale=options.locale
        ),
    )


def signed_percent(
    ratio: Decimal, *, precision: int, options: PortfolioSummaryOptions
) -> PercentageDisplay:
    """Pair a signed ratio with its ``+0.68%`` string."""
    return PercentageDisplay(
        value=ratio,
        display=signed_percentage_display(
            ratio, precision=precision, locale=options.locale
        ),
    )


def change_over(
    portfolio: Portfolio, holdings: list[Holding], options: PortfolioSummaryOptions
) -> Change:
    """Measure the portfolio against its value at the start of the range.

    ``1d`` compares to yesterday's **close** — the reference's own fact — so
    the hero agrees to the cent with the class rows beneath it. Every other
    range reads the generated history that many days back.
    """
    current = portfolio.total_market_value()
    offset = range_offset(options.range, as_of=portfolio.as_of.date())
    previous = (
        portfolio_previous_value(holdings)
        if options.range == "1d"
        else value_on(holdings, offset=offset)
    )
    delta = current - previous
    return Change(
        amount=signed_money(delta, options=options),
        percent=signed_percent(
            change_ratio(current, previous),
            precision=HERO_PERCENT_PRECISION,
            options=options,
        ),
        trend=trend_of(delta),
        period=PERIOD_LABELS[options.range],
    )


def spark(
    portfolio: Portfolio, holdings: list[Holding], options: PortfolioSummaryOptions
) -> tuple[SparkPoint, ...]:
    """The last thirty daily values, each with the day it belongs to."""
    return tuple(
        SparkPoint(
            label=date_display(point.observed_on, locale=options.locale),
            value=money(
                point.value, precision=options.precision, locale=options.locale
            ),
        )
        for point in value_series(
            holdings, as_of=portfolio.as_of.date(), points=SPARK_POINTS
        )
    )


def mover_row(mover: Mover, options: PortfolioSummaryOptions) -> MoverRow:
    """Write one mover down."""
    return MoverRow(
        symbol=mover.symbol,
        name=mover.name,
        price=money(mover.price, precision=options.precision, locale=options.locale),
        change=signed_percent(
            mover.ratio, precision=CHANGE_PERCENT_PRECISION, options=options
        ),
        trend=trend_of(mover.ratio),
    )


def movers(options: PortfolioSummaryOptions) -> tuple[MoverRow, ...]:
    """The day's top movers, written down."""
    return tuple(mover_row(row, options) for row in top_movers())


__all__ = [
    "CHANGE_PERCENT_PRECISION",
    "GREETINGS",
    "HERO_PERCENT_PRECISION",
    "change_over",
    "greeting_for",
    "mover_row",
    "movers",
    "signed_money",
    "signed_percent",
    "spark",
]
