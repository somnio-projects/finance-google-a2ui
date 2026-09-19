"""The order ``payoff`` is asked about: how big, which way, how far (spec 0014).

`payoff_limits` holds the bounds, `payoff_rows` decides how the answer reads,
and `payoff` is the tool. This module is the boundary: what the model may ask
for, enforced, and what that ask resolves to.

No free-form expression is ever interpreted from model input (ADR-K D-3), and
an undeclared or out-of-range argument is rejected rather than coerced into the
default (spec 0014 OD-5).

The size arrives as a **string** with an explicit unit, not as a number in one
of two optional fields: a JSON number from a model is a float and a float can
no longer be made exact (ADR-E D-5), and two optionals make three of their
four combinations illegal (spec 0014 OD-4).
"""

from decimal import Decimal
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.agent.tools.payoff_limits import (
    DEFAULT_RANGE_PCT,
    DEFAULT_SIDE,
    DEFAULT_SIZE_UNIT,
    DEFAULT_STEPS,
    MAX_RANGE_PCT,
    MAX_SIZE_TEXT,
    MAX_STEPS,
    MIN_RANGE_PCT,
    SIZE_PATTERN,
    SizeUnit,
)
from app.domain.money import ZERO
from app.domain.orders import order_quantity
from app.domain.payoff import MIN_STEPS, Side
from app.domain.symbols import Ticker


class PayoffArguments(BaseModel):
    """Declared arguments of ``payoff``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    symbol: Ticker = Field(
        description="Ticker of the asset the order is for, such as 'SOL'.",
        examples=["SOL"],
    )
    size: str = Field(
        pattern=SIZE_PATTERN,
        max_length=MAX_SIZE_TEXT,
        description=(
            "How big the order is, written as a positive decimal string such "
            "as '500' or '3.25'. A string, not a number, so the amount the "
            "user said is the amount that is priced."
        ),
        examples=["500", "3.25"],
    )
    size_in: SizeUnit = Field(
        default=DEFAULT_SIZE_UNIT,
        description=(
            "What 'size' counts: 'units' of the asset, or 'usd' for a dollar "
            "amount, which is converted to units at the entry price here."
        ),
        examples=["usd"],
    )
    side: Side = Field(
        default=DEFAULT_SIDE,
        description="'buy' to price the position, 'sell' to price the mirror.",
        examples=["buy"],
    )
    range_pct: int = Field(
        default=DEFAULT_RANGE_PCT,
        ge=MIN_RANGE_PCT,
        le=MAX_RANGE_PCT,
        description="How far above and below the entry price to plot, in percent.",
        examples=[DEFAULT_RANGE_PCT],
    )
    steps: int = Field(
        default=DEFAULT_STEPS,
        ge=MIN_STEPS,
        le=MAX_STEPS,
        description=(
            "Price steps on each side of the entry; the curve is twice this "
            "plus one point."
        ),
        examples=[DEFAULT_STEPS],
    )

    @model_validator(mode="after")
    def _reject_an_empty_order(self) -> Self:
        """Return the arguments, unless they ask about an order of nothing.

        Returns:
            The same instance.

        Raises:
            ValueError: When the size is zero. The pattern already excludes a
                negative one, and "what does an order for nothing make?" is
                not a question with an answer worth drawing.
        """
        if Decimal(self.size) <= ZERO:
            msg = "the order size must be greater than zero"
            raise ValueError(msg)
        return self

    def units(self, entry_price: Decimal) -> Decimal:
        """Return the order size in units of the asset.

        The dollar-to-units division happens here, in the backend, which is
        the whole point: the model states an amount and copies a quantity, it
        never divides (ADR-K D-5).

        Args:
            entry_price: The price the order is struck at; positive, because
                every price in the curated market reference is.

        Returns:
            The exact number of units the order covers.
        """
        value = Decimal(self.size)
        if self.size_in == "usd":
            return order_quantity(value, entry_price)
        return value


__all__ = ["PayoffArguments"]
