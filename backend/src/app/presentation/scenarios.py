"""What a scenario comparison *is* (spec 0017 §3, OD-8).

The shapes and the fixed sentences; ``scenario_options`` holds what a caller
may ask for, ``scenario_build`` fills these from simulated sales, and
``views/scenario_comparison.py`` is the projection itself. The same split
``sale_results.py`` and ``sales.py`` already make one layer down, forced here
by the same 150-line budget.

The shapes encode the card's promise: a comparison holds the symbol, the units
and the price **once**, in ``ScenarioSubject``, and a ``ScenarioColumn`` carries
only what the lot-selection method actually changes. A reader scanning the
columns is therefore scanning differences, not re-reading one number three
times (spec 0017 OD-3).

Nothing here ranks anything. ``ScenarioSpread`` names the two ends of the gap
because the columns already show them; it never calls either one better, and
the card ships no ``recommended`` field at all (spec 0017 OD-4).
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.lot_selection import LotMethod
from app.domain.symbols import SYMBOL_PATTERN
from app.presentation.displays import MoneyDisplay
from app.presentation.fragments import Annotation, Labelled

#: How each method is introduced to a reader who has not met it before.
METHOD_LABELS: Final[dict[LotMethod, str]] = {
    LotMethod.FIFO: "FIFO — oldest lots first",
    LotMethod.LIFO: "LIFO — newest lots first",
    LotMethod.HIFO: "HIFO — dearest lots first",
}

#: Shown on every card: what the figures are, and what the card declines to do.
NOTES: Final[tuple[Annotation, ...]] = (
    Annotation(
        label="Before tax",
        text=(
            "The realised result and its short/long split, before any tax "
            "rate, fee or wash-sale rule."
        ),
    ),
    Annotation(
        label="Not advice",
        text=(
            "No method is recommended: which result is preferable depends on "
            "a tax situation this demo does not know."
        ),
    ),
)

#: Added when the methods coincide — said plainly rather than dressed up.
SAME: Final[Annotation] = Annotation(
    label="No difference",
    text="Every method consumes the same lots here, so the figures coincide.",
)


class ScenarioSubject(Labelled):
    """What every column of one card shares — the comparability contract."""

    symbol: str = Field(
        pattern=SYMBOL_PATTERN, description="Ticker being sold.", examples=["NVDA"]
    )
    quantity_display: str = Field(
        max_length=32, description="Units the sale disposes of.", examples=["0.18"]
    )
    price: MoneyDisplay = Field(description="The price every column is costed at.")
    proceeds: MoneyDisplay = Field(
        description="``quantity * price`` — identical under every method."
    )


class ScenarioColumn(BaseModel):
    """One scenario: what this lot-selection method, and only it, changes."""

    model_config = ConfigDict(frozen=True)

    method: LotMethod = Field(description="The method this column costs.")
    label: str = Field(max_length=64, description="How the method is introduced.")
    cost_basis: MoneyDisplay = Field(description="What the consumed units cost.")
    realized_pl: MoneyDisplay = Field(description="``proceeds - cost_basis``, signed.")
    short_term_pl: MoneyDisplay = Field(description="The part taxed as short-term.")
    long_term_pl: MoneyDisplay = Field(description="The part taxed as long-term.")
    short_term_lots: int = Field(ge=0, description="Short-term lots consumed.")
    long_term_lots: int = Field(ge=0, description="Long-term lots consumed.")
    lots: tuple[str, ...] = Field(description="Lot ids, in consumption order.")


class ScenarioSpread(BaseModel):
    """How far apart the compared scenarios land — reported, never ranked."""

    model_config = ConfigDict(frozen=True)

    amount: MoneyDisplay = Field(
        description="Highest realised result minus the lowest; never negative."
    )
    differs: bool = Field(
        description="False when every method realises the same, to the cent."
    )
    highest: LotMethod | None = Field(
        default=None,
        description="Method realising the most — named, not recommended.",
    )
    lowest: LotMethod | None = Field(
        default=None, description="Method realising the least; null on a tie."
    )


__all__ = [
    "METHOD_LABELS",
    "NOTES",
    "SAME",
    "ScenarioColumn",
    "ScenarioSpread",
    "ScenarioSubject",
]
