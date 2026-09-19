"""What a proposed order makes or loses across a price range (spec 0014).

This is a **spot** payoff and nothing more. The domain holds holdings, tax
lots and a daily price (spec 0003) — no contract, no strike, no expiry, no
volatility — so the only payoff it can state honestly is the linear one:
``(price - entry) * quantity``, mirrored for a sale. Everything an options
reading of "payoff" would need is named in spec 0014 OD-8 rather than
approximated here.

It lives in the domain, beside ``return_on_cost``, because "what this order
makes at that price" is a financial statement, not a way of printing one. The
tool copies the result; the model never multiplies (ADR-K D-5).

This module is **what a payoff is**; ``app.domain.payoff_pricing`` is how one
is computed. Two files because the pair is over the 150-line budget, split
along the seam that was already there rather than by size.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import Money, Quantity
from app.domain.symbols import SYMBOL_PATTERN

Side = Literal["buy", "sell"]

#: One step on each side of the entry is the smallest grid that is still a
#: curve: a low end, the entry, a high end.
MIN_STEPS: Final[int] = 1
MIN_POINTS: Final[int] = 2 * MIN_STEPS + 1


class PayoffPoint(BaseModel):
    """The order's outcome at one price on the grid."""

    model_config = ConfigDict(frozen=True)

    price: Money = Field(description="The hypothetical price, in USD.")
    move_ratio: Decimal = Field(
        description="Where this price sits relative to the entry, as a ratio."
    )
    position_value: Money = Field(description="``quantity * price``, in USD.")
    profit_loss: Money = Field(
        description="What the order makes here; negative for a loss."
    )
    return_ratio: Decimal | None = Field(
        description=(
            "``profit_loss`` over what the order is worth at the entry price, "
            "or ``None`` for an order of zero size — a return on nothing is "
            "undefined, and reporting it as zero would call it flat."
        )
    )


class PayoffCurve(BaseModel):
    """One proposed order, priced across a bounded range around its entry."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    name: str = Field(min_length=1, max_length=64, description="Display name.")
    side: Side = Field(description="``buy`` for the position, ``sell`` for its mirror.")
    entry_price: Money = Field(description="The price the order is struck at.")
    quantity: Quantity = Field(description="Units the order covers.")
    notional: Money = Field(description="``quantity * entry_price``, in USD.")
    break_even_price: Money = Field(
        description=(
            "Where the order's profit crosses zero. The entry price for a "
            "fee-free spot order, and its own field for the day it stops "
            "being that (spec 0014 OD-9)."
        )
    )
    points: tuple[PayoffPoint, ...] = Field(
        min_length=MIN_POINTS,
        description="The curve, ascending by price, entry exactly in the middle.",
    )

    def bracket(self) -> tuple[PayoffPoint, PayoffPoint, PayoffPoint]:
        """Return the three points a reader asks about.

        Returns:
            The low end of the range, the entry, and the high end. The middle
            index **is** the entry: the grid carries ``steps`` points on each
            side of it, so the count is odd by construction (spec 0014 OD-2).
        """
        return self.points[0], self.points[len(self.points) // 2], self.points[-1]


__all__ = ["MIN_POINTS", "MIN_STEPS", "PayoffCurve", "PayoffPoint", "Side"]
