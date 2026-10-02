"""Tax lots — one acquisition of one symbol, the unit the tax flow works on.

A lot never stores its term: ``term(as_of)`` derives it from ``acquired_on``
every time (spec 0003 AC-3), so a lot cannot carry a stale classification into
a demo.
"""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import Money, Quantity
from app.domain.symbols import SYMBOL_PATTERN
from app.domain.terms import LotTerm, derive_term, holding_period_days


class TaxLot(BaseModel):
    """One open acquisition lot of one symbol."""

    model_config = ConfigDict(frozen=True)

    lot_id: str = Field(
        min_length=3, max_length=32, description="Stable identifier of the lot."
    )
    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    acquired_on: date = Field(description="The day the lot was bought (UTC).")
    quantity: Quantity = Field(gt=0, description="Units still held in this lot.")
    cost_basis: Money = Field(ge=0, description="What those units cost, in USD.")

    def term(self, as_of: date) -> LotTerm:
        """Return the lot's short/long classification at ``as_of``."""
        return derive_term(self.acquired_on, as_of=as_of)

    def held_days(self, as_of: date) -> int:
        """Return how many calendar days the lot has been held at ``as_of``.

        Deliberately the sibling of ``term`` and not a separate calculation:
        both read the same two dates through the same module, so the duration
        a row prints and the pill beside it cannot disagree (spec 0049 OD-2).
        """
        return holding_period_days(self.acquired_on, as_of=as_of)

    def market_value(self, price: Decimal) -> Decimal:
        """Return ``quantity * price`` — no rounding, ever (ADR-E D-3)."""
        return self.quantity * price

    def unrealized_pl(self, price: Decimal) -> Decimal:
        """Return the lot's unrealised profit or loss at ``price``."""
        return self.market_value(price) - self.cost_basis


__all__ = ["TaxLot"]
