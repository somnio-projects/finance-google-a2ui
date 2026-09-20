"""What a simulated sale *is* (spec 0013 §3).

Split from ``app.domain.sales``, which is what a simulated sale *does*, along
the seam the 150-line budget was going to force anyway. These are the shapes;
the walk that fills them is one import away.

The short/long split is **derived**, never stored: ``pl_in`` and ``lots_in``
read the consumed lots every time, so the split cannot disagree with the rows
it summarises. Storing it would create exactly one more number capable of
being wrong.
"""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import ZERO, Money, Quantity
from app.domain.symbols import SYMBOL_PATTERN
from app.domain.terms import LotTerm


class LotConsumption(BaseModel):
    """What the sale took out of one tax lot."""

    model_config = ConfigDict(frozen=True)

    lot_id: str = Field(
        min_length=3, max_length=32, description="The lot this row consumed."
    )
    acquired_on: date = Field(description="The day that lot was bought (UTC).")
    term: LotTerm = Field(description="Short or long, at the portfolio's as_of.")
    quantity: Quantity = Field(gt=0, description="Units taken from the lot.")
    cost_basis: Money = Field(
        ge=0, description="What those units cost — the lot's basis, pro rata."
    )
    proceeds: Money = Field(ge=0, description="``quantity * price``, in USD.")
    gain_loss: Money = Field(description="``proceeds - cost_basis``, signed.")
    exhausted: bool = Field(description="True when the sale took the whole lot.")


class SaleSimulation(BaseModel):
    """A proposed sale, costed against the lots it would consume."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker being sold.")
    price: Money = Field(gt=0, description="The price the sale is costed at.")
    quantity: Quantity = Field(gt=0, description="Units the sale disposes of.")
    proceeds: Money = Field(ge=0, description="What the sale raises, in USD.")
    cost_basis: Money = Field(ge=0, description="What the consumed units cost.")
    realized_pl: Money = Field(description="``proceeds - cost_basis``, signed.")
    remaining_quantity: Quantity = Field(
        ge=0, description="Units still held after the sale."
    )
    remaining_cost_basis: Money = Field(
        ge=0, description="Cost basis still open after the sale."
    )
    remaining_lots: int = Field(
        ge=0, description="Lots with units left after the sale."
    )
    consumed: tuple[LotConsumption, ...] = Field(
        description="The lots the sale took, in consumption order."
    )

    def pl_in(self, term: LotTerm) -> Decimal:
        """Return the realised profit or loss taxed at ``term``.

        Args:
            term: Short or long.

        Returns:
            The sum over the consumed lots of that term; zero when none is.
        """
        return sum((row.gain_loss for row in self.consumed if row.term is term), ZERO)

    def lots_in(self, term: LotTerm) -> int:
        """Return how many consumed lots fall in ``term``.

        Args:
            term: Short or long.

        Returns:
            A count, for the summary the reader compares the two halves by.
        """
        return sum(1 for row in self.consumed if row.term is term)

    def remaining_market_value(self) -> Decimal:
        """Return what the units left over are worth at the same price."""
        return self.remaining_quantity * self.price

    def closes(self) -> bool:
        """Return True when the per-lot rows sum exactly to the totals.

        Returns:
            Whether the comparator adds up. Exact, not within an epsilon:
            every figure is a ``Decimal`` derived from the same price and the
            same bases, so drift would be a real defect rather than noise
            (ADR-E D-4).
        """
        return (
            sum((row.proceeds for row in self.consumed), ZERO) == self.proceeds
            and sum((row.cost_basis for row in self.consumed), ZERO) == self.cost_basis
            and self.pl_in(LotTerm.SHORT) + self.pl_in(LotTerm.LONG) == self.realized_pl
        )


__all__ = ["LotConsumption", "SaleSimulation"]
