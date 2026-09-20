"""The arguments ``get_holdings_summary`` accepts, and what they select.

`holdings_sort` holds the orders, `holdings_rows` decides how a position
reads, and `holdings_summary` is the tool. This module is the boundary: what
the model may ask for, bounded, and what that asks resolves to.

Every knob is a declared, bounded field — no free-form expression is ever
interpreted from model input (ADR-K D-3). An undeclared or out-of-range
argument raises, and the turn loop hands the model a recoverable tool error;
it is never quietly coerced into the default (spec 0011 OD-7).
"""

from collections.abc import Mapping, Sequence
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.agent.tools.holdings_sort import (
    DEFAULT_SORT,
    SIZE_ORDERS,
    SORTERS,
    SortBy,
)
from app.domain.holdings import Holding
from app.domain.symbols import (
    MAX_TICKER,
    TICKER_PATTERN,
    Ticker,
    normalize_symbol,
)

MAX_TOP_N: Final[int] = 20
MAX_SYMBOLS: Final[int] = 20

#: The JSON Schema the model chooses its arguments from. It mirrors
#: ``HoldingsSummaryArguments``; the model reads this one, pydantic enforces
#: the other, and ``test_the_schema_the_model_reads_carries_the_same_bounds``
#: asserts the two agree rather than trusting this comment.
PARAMETERS: Final[Mapping[str, object]] = {
    "type": "object",
    "properties": {
        "sort_by": {
            "type": "string",
            "enum": list(SORTERS),
            "description": (
                "Order of the positions: 'weight' or 'value' for the largest "
                "first, 'gainers' or 'losers' for the best or worst return on "
                "what the position cost."
            ),
        },
        "symbols": {
            "type": "array",
            "items": {
                "type": "string",
                "maxLength": MAX_TICKER,
                "pattern": TICKER_PATTERN,
            },
            "maxItems": MAX_SYMBOLS,
            "description": "Keep only these tickers. Omit for every position.",
        },
        "top_n": {
            "type": "integer",
            "minimum": 1,
            "maximum": MAX_TOP_N,
            "description": "Keep only the first N positions after sorting.",
        },
    },
    "required": [],
    "additionalProperties": False,
}


class HoldingsSummaryArguments(BaseModel):
    """Validated arguments; anything undeclared is rejected (spec 0006 §5)."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    sort_by: SortBy = Field(
        default=DEFAULT_SORT, description="Which order the positions arrive in."
    )
    symbols: tuple[Ticker, ...] | None = Field(
        default=None,
        max_length=MAX_SYMBOLS,
        description="Tickers to keep; omit for the whole portfolio.",
    )
    top_n: int | None = Field(
        default=None, ge=1, le=MAX_TOP_N, description="How many positions to keep."
    )

    def _filtered(self, rows: Sequence[Holding]) -> list[Holding]:
        """Keep only the tickers this call named, or all of them."""
        if self.symbols is None:
            return list(rows)
        wanted = {normalize_symbol(symbol) for symbol in self.symbols}
        return [item for item in rows if item.symbol in wanted]

    def select(self, rows: Sequence[Holding]) -> list[Holding]:
        """Return the positions this call asks for, sorted then filtered.

        Args:
            rows: Every position in the portfolio.

        Returns:
            The rows to render: ordered by ``sort_by``, narrowed to
            ``symbols`` when given, then cut to ``top_n``. An unknown ticker
            is not an error — it simply matches nothing.
        """
        ordered = self._filtered(SORTERS[self.sort_by](rows))
        return ordered if self.top_n is None else ordered[: self.top_n]

    def chart_options(self, shown: int) -> Mapping[str, object] | None:
        """Return the allocation chart's options, or ``None`` for no chart.

        The chart draws **the whole portfolio, largest first**. It fits this
        answer only when the answer is also the whole portfolio, largest
        first: a filter, or an order by return, would put a chart under a
        sentence that contradicts it (spec 0011 OD-1).

        Args:
            shown: How many rows the answer carries.

        Returns:
            Options for ``holdings.allocation.v1``, clamped to the ``top_n``
            bound that projection declares so the intent is always valid
            against it, or ``None`` when no chart fits.
        """
        fits = self.symbols is None and self.sort_by in SIZE_ORDERS and shown > 0
        return {"top_n": min(shown, MAX_TOP_N)} if fits else None


__all__ = [
    "MAX_SYMBOLS",
    "MAX_TICKER",
    "MAX_TOP_N",
    "PARAMETERS",
    "TICKER_PATTERN",
    "HoldingsSummaryArguments",
    "Ticker",
]
