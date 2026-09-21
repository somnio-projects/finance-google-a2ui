"""What a caller may ask a scenario comparison for, and how it resolves.

The options model and the rules that turn its two ``None`` defaults into a
concrete scenario. They sit together because they are one contract: the
defaults are only honest if the rule behind each of them is written next to
the field that documents it.

``symbol`` and ``quantity`` are **scalar** and ``methods`` is the only list, so
a card comparing two symbols or two sale sizes cannot be *expressed* — the
refusal is structural rather than validated (spec 0017 OD-3).
"""

from decimal import Decimal
from typing import Annotated, Final

from pydantic import Field, field_validator

from app.core.errors import ValidationFailedError
from app.domain.lot_selection import LotMethod
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.symbols import Ticker, normalize_symbol
from app.presentation.options import DisplayOptions

#: One column per method the domain offers. Derived from the enum, so a fourth
#: method raises the cap in the commit that adds it, never in a different one.
MAX_SCENARIOS: Final[int] = len(LotMethod)
DEFAULT_METHODS: Final[tuple[LotMethod, ...]] = tuple(LotMethod)
#: Twelve integer digits — the ceiling the sale tool bounds a size with.
MAX_QUANTITY: Final[Decimal] = Decimal(10) ** 12

Units = Annotated[Decimal, Field(gt=0, le=MAX_QUANTITY, decimal_places=8)]


class ScenarioComparisonOptions(DisplayOptions):
    """Declared knobs of ``scenario.comparison.v1``; nothing else is accepted."""

    symbol: Ticker | None = Field(
        default=None,
        description=(
            "Position to cost the sale against, in any case; omit for the one "
            "whose open tax lots are worth the most, ties broken by ticker."
        ),
        examples=["NVDA"],
    )
    quantity: Units | None = Field(
        default=None,
        description=(
            "Units the sale disposes of; omit for that position's smallest "
            "open lot — the smallest sale that still makes the methods differ."
        ),
        examples=["0.18"],
    )
    methods: tuple[LotMethod, ...] = Field(
        default=DEFAULT_METHODS,
        min_length=2,
        max_length=MAX_SCENARIOS,
        description=(
            "Lot-selection methods to compare, in the order they are shown. At "
            "least two, all distinct — two identical columns would claim a "
            "difference that does not exist."
        ),
        examples=[["FIFO", "HIFO"]],
    )

    @field_validator("methods")
    @classmethod
    def _distinct(cls, value: tuple[LotMethod, ...]) -> tuple[LotMethod, ...]:
        """Reject a repeated method rather than silently deduplicating it."""
        if len(set(value)) != len(value):
            msg = "methods must be distinct"
            raise ValueError(msg)
        return value


def _largest_position(portfolio: Portfolio) -> str:
    """Return the ticker whose open lots are worth the most at ``as_of``.

    Args:
        portfolio: The portfolio to read.

    Returns:
        The canonical ticker; ties break on ascending symbol, so the rule is
        total and the documented example is byte-stable.

    Raises:
        ValidationFailedError: When the portfolio holds no open tax lots at
            all, so there is no sale to compare (spec 0017 OD-5).
    """
    worth: dict[str, Decimal] = {}
    for lot in portfolio.lots:
        value = lot.market_value(portfolio.price(lot.symbol))
        worth[lot.symbol] = worth.get(lot.symbol, ZERO) + value
    if not worth:
        msg = "this portfolio holds no open tax lots to compare a sale against"
        raise ValidationFailedError(msg)
    return min(worth, key=lambda symbol: (-worth[symbol], symbol))


def resolve(
    portfolio: Portfolio, options: ScenarioComparisonOptions
) -> tuple[str, Decimal]:
    """Turn the caller's options into the one scenario every column shares.

    Args:
        portfolio: The data the defaults resolve against.
        options: The validated options.

    Returns:
        The canonical ticker and the units to sell (spec 0017 OD-2).

    Raises:
        ValidationFailedError: When the named position holds no open lots —
            there is nothing to compare, so nothing is rendered.
    """
    symbol = (
        normalize_symbol(options.symbol)
        if options.symbol
        else _largest_position(portfolio)
    )
    lots = portfolio.tax_lots(symbol)
    if not lots:
        msg = f"no open tax lots in {symbol} to compare a sale against"
        raise ValidationFailedError(msg)
    return symbol, options.quantity or min(lot.quantity for lot in lots)


__all__ = [
    "DEFAULT_METHODS",
    "MAX_QUANTITY",
    "MAX_SCENARIOS",
    "ScenarioComparisonOptions",
    "Units",
    "resolve",
]
