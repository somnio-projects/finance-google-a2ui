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

``ScenarioSpread`` names the two ends of the gap because the columns already
show them, and it still calls neither better — a spread is a fact about the
data, not a claim about it.

**The card does rank now, and spec 0017 OD-4 is superseded rather than
broken.** *"No ``recommended`` field at all"* was the right ruling while there
was no tax rate to rank by: which result is preferable depended on a tax
situation the demo did not know. GGU-134 made the rate a **declared, printed
assumption**, so the ranking became arithmetic the reader can check, and
``scenario_verdict`` performs it — once, with the *Not advice* note still on
the card (spec 0051 OD-1).
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.lot_selection import LotMethod
from app.domain.symbols import SYMBOL_PATTERN
from app.presentation.displays import MoneyDisplay
from app.presentation.fragments import Annotation, Labelled

# Re-exported: the column moved out for the file budget when it grew its
# after-tax rows, and every caller was already importing it from here.
from app.presentation.scenario_columns import ScenarioColumn

#: How each method is introduced to a reader who has not met it before.
METHOD_LABELS: Final[dict[LotMethod, str]] = {
    LotMethod.FIFO: "FIFO — oldest lots first",
    LotMethod.LIFO: "LIFO — newest lots first",
    LotMethod.HIFO: "HIFO — dearest lots first",
}

#: Shown on every card: what the figures are, and what the card declines to do.
NOTES: Final[tuple[Annotation, ...]] = (
    Annotation(
        label="Illustrative rates",
        text=(
            "Tax is estimated at {short} on the short-term part and {long} "
            "on the long-term part, on gains only. These rates are a "
            "declared assumption, not yours: no fee and no wash-sale rule is "
            "modelled."
        ),
    ),
    Annotation(
        label="Not advice",
        text=(
            "The recommendation is arithmetic under the rates above, not "
            "advice: which result is preferable depends on a tax situation "
            "this demo does not know."
        ),
    ),
)

#: Added when the timing column is asked for: it holds the price still, which
#: a year does not, and a column that implied a forecast would be worse than
#: no column (spec 0051 OD-2).
WAITS: Final[Annotation] = Annotation(
    label="Waiting assumes today's price",
    text=(
        "The *Wait for long-term* column costs the same sale past every "
        "lot's first anniversary at today's price. It shows what the holding "
        "period is worth, not what the asset will be."
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
        pattern=SYMBOL_PATTERN, description="Ticker being sold.", examples=["BTC"]
    )
    quantity_display: str = Field(
        max_length=32, description="Units the sale disposes of.", examples=["0.18"]
    )
    price: MoneyDisplay = Field(description="The price every column is costed at.")
    proceeds: MoneyDisplay = Field(
        description="``quantity * price`` — identical under every method."
    )


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
    "WAITS",
    "ScenarioColumn",
    "ScenarioSpread",
    "ScenarioSubject",
]
