"""What ``simulate_sale`` accepts (spec 0013).

The other half of the tool: this decides *what was asked for*, the tool module
decides what to do about it. Split under the 150-line budget along that seam,
the same way the holdings tool splits its query from its rows.

The position and the size live in ``sale_size``, because
``compare_lot_methods`` names them the same way (spec 0052). What is left here
is the one field that is this tool's own: **which** lots the sale consumes.
The comparison tool's answer to that question is a list, which is the whole
difference between the two tools.

``SIZE_PATTERN``, ``TICKER_PATTERN``, ``MAX_TICKER`` and ``Method`` are
re-exported so a reader who knows where they used to live still finds them.
"""

from typing import Final

from pydantic import Field

from app.agent.tools.sale_size import (
    MAX_TICKER,
    SIZE_PATTERN,
    TICKER_PATTERN,
    Method,
    SaleSizeArguments,
)
from app.domain.lot_selection import LotMethod

#: The default this tool costs a sale under when the model names no method.
DEFAULT_METHOD: Final[Method] = "FIFO"


class SimulateSaleArguments(SaleSizeArguments):
    """Declared arguments of ``simulate_sale``; nothing else is accepted."""

    lot_method: Method = Field(
        default=DEFAULT_METHOD,
        description=(
            "Which lots the sale consumes first: FIFO the oldest, LIFO the "
            "newest, HIFO the dearest — the one that realises the least gain."
        ),
        examples=["FIFO"],
    )

    def method(self) -> LotMethod:
        """Return the lot-selection policy as the domain's own enum."""
        return LotMethod(self.lot_method)


__all__ = [
    "DEFAULT_METHOD",
    "MAX_TICKER",
    "SIZE_PATTERN",
    "TICKER_PATTERN",
    "Method",
    "SimulateSaleArguments",
]
