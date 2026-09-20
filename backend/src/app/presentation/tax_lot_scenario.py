"""What the tax-lot table **accepts** (spec 0015 §3).

The sale this view renders is not in the portfolio, so the caller has to name
it: which symbol, how many units, which lots go first. ADR-K D-3 already says
how a caller names anything — declared, bounded, defaulted, described options —
so the scenario is three more fields on the options model rather than a second
argument to ``render`` (spec 0015 OD-1).

The same seam ``app/agent/tools/sale_request.py`` cuts for the tool: what was
asked for, apart from what is done about it.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.domain.lot_selection import LotMethod
from app.domain.symbols import Ticker
from app.presentation import options as opt

#: Spelled here because this layer may not import ``app.agent``, where the tool
#: declares the same bound. A second occurrence; a third moves it (0015 OD-3).
SIZE_PATTERN: Final[str] = r"^\d{1,12}(\.\d{1,8})?$"

#: BTC's two lots straddle the one-year boundary, so the default scenario — the
#: one the documented example renders — shows both halves of the split.
DEFAULT_SYMBOL: Final[str] = "BTC"
DEFAULT_QUANTITY: Final[str] = "0.5"


class TaxLotsTableOptions(opt.DisplayOptions, opt.FieldSelection):
    """Declared knobs of ``tax_lots.table.v1``; nothing else is accepted."""

    symbol: Ticker = Field(
        default=DEFAULT_SYMBOL,
        description="Ticker being sold, in any case.",
        examples=["BTC"],
    )
    quantity: str = Field(
        default=DEFAULT_QUANTITY,
        pattern=SIZE_PATTERN,
        description=(
            "Units to sell, written as a decimal string ('0.5'). A dollar-sized "
            "ask is resolved to units by the `simulate_sale` tool; copy the "
            "units it returned rather than dividing (spec 0015 OD-4)."
        ),
        examples=["0.5"],
    )
    lot_method: Literal["FIFO", "LIFO", "HIFO"] = Field(
        default="FIFO",
        description=(
            "Which lots the sale consumes first: FIFO the oldest, LIFO the "
            "newest, HIFO the dearest."
        ),
        examples=["FIFO"],
    )

    def units(self) -> Decimal:
        """Return the sale size as the exact ``Decimal`` the domain walks."""
        return Decimal(self.quantity)

    def method(self) -> LotMethod:
        """Return the lot-selection policy as the domain's own enum."""
        return LotMethod(self.lot_method)


__all__ = [
    "DEFAULT_QUANTITY",
    "DEFAULT_SYMBOL",
    "SIZE_PATTERN",
    "TaxLotsTableOptions",
]
