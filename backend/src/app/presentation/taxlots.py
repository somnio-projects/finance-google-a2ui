"""What the tax-lot table's payload **is** (spec 0015 §4).

Split from ``taxlot_render``, which is how it is **built**, along the seam
spec 0013 already cut through the same data — and the one the 150-line budget
was going to force anyway (spec 0015 OD-7). These are the shapes; the pure
builders that fill them are one import away.

They live beside ``fragments.py`` rather than inside it because no second
projection needs a tax lot yet (ADR-K D-16): the tenth chart reuses the shared
vocabulary, and a primitive is promoted into it when a **second** view asks
for one, not in anticipation.

**What is no longer here** (spec 0024 §7): the ``price`` total and the
``remaining[]`` notes. Both were served, neither drawn — no design slot, and
PR #71 binds neither. A field nothing binds is a field nobody maintains, so it
is wrong before anyone notices. ``cost_basis`` and ``proceeds`` stayed: their
*labels* are two of the table's column captions, which the component binds.
"""

from datetime import date
from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.domain.terms import LotTerm
from app.presentation.fragments import (
    Labelled,
    MoneyDisplay,
    ProjectionDto,
    Total,
)

VIEW_ID: Final[str] = "taxlots.table.v1"

#: The human half of ``LotTerm``. A mapping keyed by the enum, so a term can
#: only be labelled by being a term — there is no string to mistype.
TERM_LABELS: Final[dict[LotTerm, str]] = {
    LotTerm.SHORT: "Short-term",
    LotTerm.LONG: "Long-term",
}


class TaxLotRow(Labelled):
    """One consumed tax lot, as the table prints it.

    ``label`` is the lot id: for a lot it is both the stable key a widget
    binds by and the text the row shows, so `Category`'s key/label pair would
    be the same string twice.
    """

    acquired_on: date = Field(description="The day the lot was bought (UTC).")
    acquired_on_display: str = Field(
        max_length=32,
        description=(
            "The same day, written for a reader under the view's `locale`. "
            "The pair, not the raw date alone: re-spelling `2025-01-13` in "
            "the client is formatting, so without this the ISO string reached "
            "the screen (spec 0024 §7, GGU-99 gap 1)."
        ),
        examples=["01/13/2025"],
    )
    term: LotTerm = Field(
        description="Short or long at the portfolio's `as_of`, from the lot itself.",
        examples=["long"],
    )
    units: Decimal = Field(
        description="Units taken from this lot — exact, for geometry, never printed.",
        examples=["0.42"],
    )
    units_display: str = Field(
        max_length=32,
        description=(
            "Those units, pre-formatted (spec 0015 OD-9). The printable half "
            "of the pair the Shares column binds; `units` is the raw figure "
            "N-4 reserves for a chart (GGU-99 gap 2)."
        ),
        examples=["0.42"],
    )
    cost_basis: MoneyDisplay = Field(description="What those units cost, pro rata.")
    proceeds: MoneyDisplay = Field(description="What those units raise at the price.")
    gain_loss: MoneyDisplay = Field(
        description="`proceeds - cost_basis` for this lot, signed."
    )
    trend: str = Field(
        max_length=8,
        description="Direction of the row's result, so the widget colours it.",
        examples=["up"],
    )
    fully_sold: bool = Field(
        description="True when the sale took the whole lot; False when it stopped "
        "part-way through it.",
        examples=[True],
    )


class TermTotal(Labelled):
    """One half of the short/long split — the point of the whole surface."""

    term: LotTerm = Field(
        description="Which holding period this half totals.", examples=["short"]
    )
    lots: int = Field(
        ge=0, description="How many consumed lots fall in it.", examples=[1]
    )
    realized: MoneyDisplay = Field(
        description="Realised profit or loss taxed at this term, signed."
    )


class TaxLotsTablePayload(ProjectionDto):
    """The lots a proposed sale consumes, and what each one realises."""

    view: Literal["taxlots.table.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120,
        description="Title the widget shows.",
        examples=["Tax lots this sale consumes"],
    )
    subtitle: str = Field(
        max_length=200,
        description="The scenario in words, written here so the client states no "
        "figure of its own.",
        examples=["Sell 0.5 BTC under FIFO"],
    )
    proceeds: Total = Field(
        description="What the sale raises; its `label` captions that column."
    )
    cost_basis: Total = Field(
        description="What the units cost; its `label` captions that column."
    )
    realized: Total = Field(description="`proceeds - cost_basis`, signed.")
    by_term: tuple[TermTotal, ...] = Field(
        description="The short/long split: one entry per term, always, in term "
        "order, even when the sale touched only one of them."
    )
    lots: tuple[TaxLotRow, ...] = Field(
        default=(), description="One row per consumed lot, in consumption order."
    )


__all__ = [
    "TERM_LABELS",
    "VIEW_ID",
    "TaxLotRow",
    "TaxLotsTablePayload",
    "TermTotal",
]
