"""What the order does, and the bound it is checked against (spec 0031).

Split from ``order_ticket_v2_payload`` when the ticket grew its ``controls``
and went past the file budget, along the seam that was already there: what the
draft **costs and shifts**, apart from what the **ticket** carries. The two
badges live here too, because both are read off a breach.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.draft_legs import MAX_LEGS
from app.presentation.fragments import MoneyDisplay, Total
from app.presentation.order_ticket_v2_lines import WeightShift

Breach = Literal["none", "over_cash"]
Badge = Literal["editable", "blocked"]


class OrderImpact(BaseModel):
    """The design's *Order impact* panel, every figure pre-formatted."""

    model_config = ConfigDict(frozen=True)

    total: Total = Field(description="What the whole order is worth.")
    fees: Total = Field(description="Simulated fees — zero, and labelled so.")
    cash_remaining: Total = Field(
        description="Cash left after the order; negative when it is blocked."
    )
    weight_shifts: tuple[WeightShift, ...] = Field(
        max_length=MAX_LEGS,
        description="One row per group the legs touch, first-leg order.",
    )


class OrderConstraints(BaseModel):
    """The bound a draft is checked against, and whether it breached it."""

    model_config = ConfigDict(frozen=True)

    max_cash: Total = Field(description="Cash available to a buy.")
    breach: Breach = Field(
        description="Which bound the draft exceeds; `none` when it is fillable.",
        examples=["none"],
    )
    shortfall: MoneyDisplay | None = Field(
        default=None,
        description="How far over the bound the draft is; null when it is not.",
    )
    message: str | None = Field(
        default=None,
        max_length=160,
        description="The validation sentence to show verbatim; null when none.",
        examples=["Exceeds available cash — reduce order by $2,300.00."],
    )


__all__ = ["Badge", "Breach", "OrderConstraints", "OrderImpact"]
