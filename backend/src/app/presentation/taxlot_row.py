"""One consumed tax lot, as the table prints it (spec 0015 §4, 0049 OD-2).

Split out of ``taxlots`` when the holding-period field pushed that file over
the 150-line budget, named after the view as the group's other modules are
(``taxlot_scenario``, ``taxlot_render``). ``taxlots`` re-exports it, so the
payload and its row are still one import for a reader.

The seam is the one the payload already implies: this is **a row**, and what is
left in ``taxlots`` is the card the rows sit in and the split beneath them.
"""

from datetime import date
from decimal import Decimal

from pydantic import Field

from app.domain.terms import LotTerm
from app.presentation.fragments import MoneyDisplay
from app.presentation.labels import Labelled


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
    holding_period_display: str = Field(
        max_length=16,
        description=(
            "How long the lot has been held, worded here so the client never "
            "subtracts two dates (N-13 bans the device clock outright). Days "
            "up to and including the 365-day boundary, years beyond it, so "
            "this string and `term` always agree (spec 0049 OD-2). There is "
            "no numeric twin: nothing plots a duration (OD-3)."
        ),
        examples=["5.5 yr"],
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


__all__ = ["TaxLotRow"]
