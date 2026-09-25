"""What ``simulate_sale`` accepts, and how a sale size is resolved (spec 0013).

The other half of the tool: this decides *what was asked for*, the tool module
decides what to do about it. Split under the 150-line budget along that seam,
the same way the holdings tool splits its query from its rows.

**Sizes cross as decimal strings, not JSON numbers** (OD-2). ADR-E D-1 forbids
``float`` in the portfolio domain and ``app.domain.money.reject_float``
enforces it: ``0.1`` parsed from JSON is already
``0.1000000000000000055…`` before this code runs, and no later conversion
repairs it. A pattern-bounded string is the only way for the model to name an
exact quantity.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.display import QUANTITY_PRECISION
from app.core.locales import quantize
from app.domain.errors import SaleQuantityError
from app.domain.lot_selection import LotMethod

#: At most 12 integer and 8 fractional digits — bounded like every other
#: declared option (ADR-K D-3), so the size cannot be used to make the lot
#: walk do work proportional to the input.
SIZE_PATTERN: Final[str] = r"^\d{1,12}(\.\d{1,8})?$"
MAX_TICKER: Final[int] = 10

#: The model's spelling of ``app.domain.symbols.SYMBOL_PATTERN``, which only
#: matches the canonical upper-case form. Case and surrounding whitespace are
#: normalised downstream, so both are accepted here — but ``"b$"`` is not, and
#: is rejected as an argument instead of reaching the market reference and
#: coming back to the model as an opaque ``tool-failed``. ``max_length`` is
#: what bounds the input; the ``\s*`` runs cannot grow past it.
TICKER_PATTERN: Final[str] = r"^\s*[A-Za-z]{2,10}\s*$"

#: Spelled as a ``Literal`` rather than as ``LotMethod`` so the generated JSON
#: Schema inlines the three values instead of emitting a ``$ref`` the model
#: would have to resolve. ``method()`` converts back to the domain enum.
Method = Literal["FIFO", "LIFO", "HIFO"]


class SimulateSaleArguments(BaseModel):
    """Declared arguments of ``simulate_sale``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    symbol: str = Field(
        min_length=2,
        max_length=MAX_TICKER,
        pattern=TICKER_PATTERN,
        description="Ticker to sell, such as BTC.",
        examples=["BTC"],
    )
    quantity: str | None = Field(
        default=None,
        pattern=SIZE_PATTERN,
        description=(
            "Units to sell, written as a decimal string ('0.5'). Give this or "
            "amount_usd, never both and never neither."
        ),
        examples=["0.5"],
    )
    amount_usd: str | None = Field(
        default=None,
        pattern=SIZE_PATTERN,
        description=(
            "Dollars to raise, written as a decimal string ('10000'). "
            "Resolved to units at the current price."
        ),
        examples=["10000.00"],
    )
    lot_method: Method = Field(
        default="FIFO",
        description=(
            "Which lots the sale consumes first: FIFO the oldest, LIFO the "
            "newest, HIFO the dearest — the one that realises the least gain."
        ),
        examples=["FIFO"],
    )

    def method(self) -> LotMethod:
        """Return the lot-selection policy as the domain's own enum."""
        return LotMethod(self.lot_method)

    def units(self, price: Decimal) -> Decimal:
        """Resolve the requested size into a number of units to sell.

        A dollar amount is divided by the price and **quantized to 8 decimal
        places before anything is computed from it** (OD-4). A trade size is
        an input, not an intermediate figure, so rounding it is not the
        rounding ADR-E D-3 forbids — and it is what makes the whole payload
        hand-checkable: proceeds are exactly the displayed quantity times the
        displayed price, with no leftover cent to explain.

        Args:
            price: The current reference price of the symbol.

        Returns:
            The exact number of units the simulation should dispose of.

        Raises:
            SaleQuantityError: When neither size or both sizes were given.
                The rule lives here because this is the only place the two
                fields mean anything together; the turn loop hands the model a
                recoverable tool error and it asks again (spec 0011 OD-7 — a
                rejection, never a best-effort guess at which one was meant).
        """
        if self.quantity is not None and self.amount_usd is None:
            return Decimal(self.quantity)
        if self.amount_usd is not None and self.quantity is None:
            return quantize(
                Decimal(self.amount_usd) / price, precision=QUANTITY_PRECISION
            )
        msg = "a sale takes exactly one of quantity or amount_usd"
        raise SaleQuantityError(msg)


__all__ = [
    "MAX_TICKER",
    "SIZE_PATTERN",
    "TICKER_PATTERN",
    "Method",
    "SimulateSaleArguments",
]
