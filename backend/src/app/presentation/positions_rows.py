"""Write one holding down as a Holdings-tab row (spec 0028)."""

from collections.abc import Sequence
from decimal import Decimal
from typing import Final

from pydantic import Field

from app.core.display import quantity_display
from app.core.signed_display import signed_money_display, signed_percentage_display
from app.domain.day_change import change_ratio, previous_value, trend_of
from app.domain.holdings import Holding
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.taxonomy import AssetClass
from app.presentation.displays import MoneyDisplay, PercentageDisplay, money, percentage
from app.presentation.options import DisplayOptions, SortOptions
from app.presentation.positions_payload import (
    ALL_CLASSES,
    ASK_LABEL,
    CASH_DETAIL,
    GAIN_PERIOD,
    AssetFilter,
    Position,
)
from app.presentation.search import SearchOptions
from app.presentation.summary_payload import Change, Question

#: The design prints the day move and the weight to one decimal, the
#: unrealised amount to whole dollars and its percentage to one decimal.
ONE_DECIMAL: Final[int] = 1
WHOLE_DOLLARS: Final[int] = 0


class HoldingsPositionsOptions(DisplayOptions, SortOptions, SearchOptions):
    """The display knobs, the row order, and the two filters (spec 0035)."""

    asset_class: AssetFilter = Field(
        default=ALL_CLASSES,
        description="Keep only this asset class; `all` keeps every row.",
        examples=["layer1"],
    )


def is_cash(holding: Holding) -> bool:
    """Whether ``holding`` is the settlement asset — the stablecoin (0044)."""
    return market_asset(holding.symbol).asset_class is AssetClass.STABLECOIN


def gain_of(value: Decimal, cost: Decimal, *, period: str, locale: str) -> Change:
    """The signed result of holding something bought for ``cost``."""
    delta = value - cost
    ratio = change_ratio(value, cost)
    return Change(
        amount=MoneyDisplay(
            amount=delta,
            display=signed_money_display(delta, precision=WHOLE_DOLLARS, locale=locale),
        ),
        percent=PercentageDisplay(
            value=ratio,
            display=signed_percentage_display(
                ratio, precision=ONE_DECIMAL, locale=locale
            ),
        ),
        trend=trend_of(delta),
        period=period,
    )


def detail_of(holding: Holding, *, locale: str) -> str:
    """``90 sh · avg $826.67`` — or the settlement fund's caption."""
    if is_cash(holding):
        return CASH_DETAIL
    shares = quantity_display(holding.quantity, locale=locale, trim=True)
    average = money(holding.cost_basis / holding.quantity, locale=locale).display
    return f"{shares} sh · avg {average}"


def question_for(holding: Holding) -> Question:
    """The question the hand-off sends; the device never composes one."""
    if is_cash(holding):
        return Question(text="What is my cash doing?")
    return Question(text=f"Tell me about my {holding.symbol} position")


def position_of(holding: Holding, options: HoldingsPositionsOptions) -> Position:
    """Write ``holding`` down as one row."""
    locale = options.locale
    day_ratio = change_ratio(holding.market_value, previous_value(holding))
    cash = is_cash(holding)
    return Position(
        symbol=holding.symbol,
        name=holding.name,
        detail=detail_of(holding, locale=locale),
        value=money(holding.market_value, precision=options.precision, locale=locale),
        unrealized=None
        if cash
        else gain_of(
            holding.market_value, holding.cost_basis, period="all-time", locale=locale
        ),
        day=PercentageDisplay(
            value=day_ratio,
            display=signed_percentage_display(
                day_ratio, precision=ONE_DECIMAL, locale=locale
            ),
        ),
        day_trend=trend_of(day_ratio),
        price=money(holding.price, locale=locale),
        weight=percentage(holding.weight, precision=ONE_DECIMAL, locale=locale),
        is_cash=cash,
        ask=question_for(holding),
    )


def ordered(holdings: Sequence[Holding], sort: str) -> list[Holding]:
    """The rows in the requested order; cash last whenever value decides."""
    if sort == "label":
        return sorted(holdings, key=lambda row: row.name.lower())
    by_value = sorted(
        holdings, key=lambda row: row.market_value, reverse=sort == "value_desc"
    )
    return [row for row in by_value if not is_cash(row)] + [
        row for row in by_value if is_cash(row)
    ]


def total_gain(holdings: Sequence[Holding], *, locale: str) -> Change:
    """The all-time unrealised result of everything held."""
    value = sum((row.market_value for row in holdings), ZERO)
    cost = sum((row.cost_basis for row in holdings), ZERO)
    return gain_of(value, cost, period=GAIN_PERIOD, locale=locale)


__all__ = [
    "ASK_LABEL",
    "HoldingsPositionsOptions",
    "detail_of",
    "gain_of",
    "is_cash",
    "ordered",
    "position_of",
    "question_for",
    "total_gain",
]
