"""One column of a scenario comparison (spec 0051).

Split from ``scenarios`` at the file budget when the redesign gave a column
four things it did not have: a caption, an estimated tax, a net after it, and
whether it is the one recommended.

**A column is no longer always a lot method.** The frame draws a third,
*"Wait for long-term"*, captioned *"> 12 mo hold"* — which is not an ordering
of lots but a different **time** to sell. ``kind`` says which a column is, so
``method``'s enum keeps meaning exactly one thing (spec 0051 OD-2).
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.lot_selection import LotMethod
from app.presentation.displays import MoneyDisplay

#: What a column varies. ``lot_method`` changes which lots are consumed;
#: ``timing`` changes when the sale happens, holding the method fixed.
ColumnKind = Literal["lot_method", "timing"]


class ScenarioColumn(BaseModel):
    """One scenario: what this column, and only it, changes."""

    model_config = ConfigDict(frozen=True)

    key: str = Field(
        max_length=32,
        pattern=r"^[a-z0-9-]+$",
        description=(
            "Stable id a row's `winner` names. Not `method`: the timing "
            "column shares a method with a lot-ordering one, so a method is "
            "no longer unique across columns."
        ),
        examples=["hifo"],
    )
    method: LotMethod = Field(description="The method this column costs.")
    kind: ColumnKind = Field(
        default="lot_method",
        description="Whether the column varies the lot ordering or the timing.",
        examples=["lot_method"],
    )
    label: str = Field(max_length=64, description="How the method is introduced.")
    caption: str = Field(
        max_length=48,
        description="The short line under the column head, server-written.",
        examples=["default order"],
    )
    proceeds: MoneyDisplay = Field(
        description=(
            "What the sale raises. Identical in every column by construction "
            "— the card's premise is one sale — and repeated here so the "
            "row-major table is uniform. Its row therefore always ties, and "
            "the frame draws no tick on it (spec 0051 OD-3)."
        )
    )
    cost_basis: MoneyDisplay = Field(description="What the consumed units cost.")
    realized_pl: MoneyDisplay = Field(description="``proceeds - cost_basis``, signed.")
    short_term_pl: MoneyDisplay = Field(description="The part taxed as short-term.")
    long_term_pl: MoneyDisplay = Field(description="The part taxed as long-term.")
    est_tax: MoneyDisplay = Field(
        description="Tax at the declared rates, on gains only (spec 0051 OD-1)."
    )
    net_after_tax: MoneyDisplay = Field(
        description="``realized_pl - est_tax`` — what the seller keeps."
    )
    short_term_lots: str = Field(
        description="Short-term lots consumed, as a decimal string.",
        pattern=r"^[0-9]{1,4}$",
        examples=["2"],
    )
    long_term_lots: str = Field(
        description="Long-term lots consumed, as a decimal string.",
        pattern=r"^[0-9]{1,4}$",
        examples=["1"],
    )
    recommended: bool = Field(
        default=False,
        description=(
            "Whether this column keeps the most after tax. A server decision: "
            "comparing two figures is N-2 on the client."
        ),
        examples=[False],
    )
    recommendation_label: str | None = Field(
        default=None,
        max_length=32,
        description="The tag drawn on the recommended column; null on the rest.",
        examples=["Recommended"],
    )
    lots: tuple[str, ...] = Field(description="Lot ids, in consumption order.")


__all__ = ["ColumnKind", "ScenarioColumn"]
