"""Which positions ``get_holdings_summary`` answers with, and in which order.

The other half of the tool: `holdings_rows` decides how a position *reads*,
this decides *which* ones and in *what order*, and `holdings_summary` is the
tool that puts the two together. Split under the 150-line budget along that
seam rather than by size.

Every knob is a declared, bounded field — no free-form expression is ever
interpreted from model input (ADR-K D-3). An undeclared or out-of-range
argument raises, and the turn loop hands the model a recoverable tool error;
it is never quietly coerced into the default (spec 0011 OD-7).
"""

from collections.abc import Callable, Mapping, Sequence
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.holdings import Holding
from app.domain.money import ZERO
from app.domain.returns import return_on_cost
from app.domain.symbols import normalize_symbol

MAX_TOP_N: Final[int] = 20
MAX_SYMBOLS: Final[int] = 20
MAX_TICKER: Final[int] = 10

SortBy = Literal["weight", "value", "gainers", "losers"]
DEFAULT_SORT: Final[SortBy] = "weight"


def _return_key(holding: Holding, *, descending: bool) -> tuple[bool, object, str]:
    """Order by return on cost, positions without one last, ties by symbol."""
    ratio = return_on_cost(holding.unrealized_pl, holding.cost_basis)
    value = ZERO if ratio is None else ratio
    return (ratio is None, -value if descending else value, holding.symbol)


def _by_value(rows: Sequence[Holding]) -> list[Holding]:
    """Order by market value descending — which is also weight descending."""
    return sorted(rows, key=lambda item: (-item.market_value, item.symbol))


#: Row order per ``sort_by``. ``weight`` and ``value`` are the same ordering by
#: construction: weight is market value over a total that does not vary within
#: one call (spec 0011 OD-4).
SORTERS: Final[dict[str, Callable[[Sequence[Holding]], list[Holding]]]] = {
    "weight": _by_value,
    "value": _by_value,
    "gainers": lambda rows: sorted(rows, key=lambda h: _return_key(h, descending=True)),
    "losers": lambda rows: sorted(rows, key=lambda h: _return_key(h, descending=False)),
}

#: The JSON Schema the model chooses its arguments from. It mirrors
#: ``HoldingsSummaryArguments``; the model reads this one, pydantic enforces
#: the other, and a test asserts the two agree.
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
            "items": {"type": "string", "maxLength": MAX_TICKER},
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
    symbols: tuple[str, ...] | None = Field(
        default=None,
        max_length=MAX_SYMBOLS,
        description="Tickers to keep; omit for the whole portfolio.",
    )
    top_n: int | None = Field(
        default=None, ge=1, le=MAX_TOP_N, description="How many positions to keep."
    )

    def select(self, rows: Sequence[Holding]) -> list[Holding]:
        """Return the positions this call asks for, sorted then filtered.

        Args:
            rows: Every position in the portfolio.

        Returns:
            The rows to render: ordered by ``sort_by``, narrowed to
            ``symbols`` when given, then cut to ``top_n``. An unknown ticker
            is not an error — it simply matches nothing.
        """
        ordered = SORTERS[self.sort_by](rows)
        if self.symbols is not None:
            wanted = {normalize_symbol(symbol) for symbol in self.symbols}
            ordered = [item for item in ordered if item.symbol in wanted]
        return ordered if self.top_n is None else ordered[: self.top_n]


__all__ = [
    "DEFAULT_SORT",
    "MAX_SYMBOLS",
    "MAX_TICKER",
    "MAX_TOP_N",
    "PARAMETERS",
    "SORTERS",
    "HoldingsSummaryArguments",
    "SortBy",
]
