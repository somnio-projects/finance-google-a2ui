"""The order ``payoff.curve.v1`` is asked about, declared and bounded.

A payoff curve is a chart of something that does not exist yet, so the thing
it draws cannot come from the portfolio: it comes from **declared options**
(ADR-K D-3). This module is that declaration — which asset, how big, which
way, how far and how finely — and the one conversion the caller must never do
itself, dollars to units.

It sits beside ``views/`` rather than inside it because every module in that
package is a registered view, asserted by
``tests/unit/presentation/test_package_boundaries.py`` (spec 0016 OD-5).

Every bound here is a **security property**, the same way spec 0014 §5 treats
the tool's: ``steps`` at 25 and ``range_pct`` at 90 make the largest line this
projection can be made to draw 51 points, whatever the model asks for.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.domain.orders import order_quantity
from app.domain.payoff import MIN_STEPS, Side
from app.domain.symbols import Symbol
from app.presentation import options as opt

#: The curated market reference as a closed option domain: an unknown ticker
#: is a 422 from this model rather than a ``SymbolNotFoundError`` raised from
#: inside a presenter, and the generated prompt fragment lists the eight the
#: model may ask for (spec 0016 OD-3).
SizeUnit = Literal["units", "usd"]

MAX_SIZE: Final[int] = 1_000_000_000
MIN_RANGE_PCT: Final[int] = 5
MAX_RANGE_PCT: Final[int] = 90
MAX_STEPS: Final[int] = 25


class PayoffCurveOptions(opt.DisplayOptions, opt.FieldSelection):
    """Declared knobs of ``payoff.curve.v1``; nothing else is accepted."""

    symbol: Symbol = Field(
        default="SOL", description="Asset the order is for.", examples=["SOL"]
    )
    size: int = Field(
        default=500,
        ge=1,
        le=MAX_SIZE,
        description=(
            "How big the order is, counted in `size_in`. A whole number: a "
            "JSON float can no longer be made exact (ADR-E D-5)."
        ),
        examples=[500],
    )
    size_in: SizeUnit = Field(
        default="usd",
        description="What `size` counts: units of the asset, or US dollars.",
        examples=["usd"],
    )
    side: Side = Field(
        default="buy",
        description="`buy` plots the position, `sell` plots its mirror.",
        examples=["buy"],
    )
    range_pct: int = Field(
        default=30,
        ge=MIN_RANGE_PCT,
        le=MAX_RANGE_PCT,
        description="How far above and below the entry price to plot, in percent.",
        examples=[30],
    )
    steps: int = Field(
        default=12,
        ge=MIN_STEPS,
        le=MAX_STEPS,
        description="Price steps per side; the line is twice this plus one point.",
        examples=[12],
    )

    def quantity(self, entry_price: Decimal) -> Decimal:
        """Return the order size in units of the asset.

        Args:
            entry_price: The price the order is struck at; positive, as every
                price in the curated reference is.

        Returns:
            ``size`` itself when it already counts units, and the exact,
            unrounded quotient when it counts dollars — the division happens
            here, never in the model and never in the client (ADR-K D-5).
        """
        value = Decimal(self.size)
        if self.size_in == "usd":
            return order_quantity(value, entry_price)
        return value


__all__ = [
    "MAX_RANGE_PCT",
    "MAX_SIZE",
    "MAX_STEPS",
    "MIN_RANGE_PCT",
    "PayoffCurveOptions",
    "SizeUnit",
    "Symbol",
]
