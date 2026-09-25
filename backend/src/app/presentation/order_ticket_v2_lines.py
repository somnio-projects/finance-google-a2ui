"""The fragments of one rendered leg of ``order.ticket.v2`` (spec 0031).

Split from ``order_ticket_v2_payload`` for the file budget, along the seam
that was already there: what one **leg** carries, apart from what the
**ticket** carries. Not promoted to ``fragments.py``: ADR-K D-16 promotes a
primitive when a second consumer needs it, and a stepper has one.

``increment`` and ``decrement`` are the stepper. A client may not add one to a
unit count (N-2), so each is the whole ``legs`` option value the tap sends,
written here from the same parser and bound the options model enforces. A
``null`` means the move would leave the published bound, and the control is
disabled rather than sending a value the backend refuses (spec 0031 OD-3).
"""

from pydantic import BaseModel, ConfigDict, Field

from app.domain.draft_legs import LEGS_PATTERN, MAX_LEGS_TEXT
from app.presentation.fragments import Labelled, MoneyDisplay, PercentageDisplay
from app.presentation.ticket_displays import QuantityDisplay


class OrderLine(BaseModel):
    """One leg of the draft, struck and weighed, with its stepper values."""

    model_config = ConfigDict(frozen=True)

    key: str = Field(max_length=10, description="Stable id: the ticker.")
    symbol: str = Field(max_length=10, description="Ticker.", examples=["BTC"])
    name: str = Field(
        max_length=64, description="Asset name.", examples=["NVIDIA Corp"]
    )
    price: MoneyDisplay = Field(description="Reference price a unit is struck at.")
    quantity: QuantityDisplay = Field(
        description="Units of this asset the leg covers, in the asset's own units."
    )
    notional: MoneyDisplay = Field(description="What the leg is worth at that price.")
    weight: PercentageDisplay = Field(description="The leg's share of the order.")
    increment: str | None = Field(
        max_length=MAX_LEGS_TEXT,
        pattern=LEGS_PATTERN,
        description="The `legs` value a `+` sends; null when at the bound.",
        examples=["BTC:4,ETH:2,SOL:14"],
    )
    decrement: str | None = Field(
        max_length=MAX_LEGS_TEXT,
        pattern=LEGS_PATTERN,
        description="The `legs` value a `-` sends; null at zero units.",
        examples=["BTC:2,ETH:2,SOL:14"],
    )


class WeightShift(Labelled):
    """A group's share of the portfolio before and after the order."""

    key: str = Field(max_length=32, description="Group id.", examples=["technology"])
    before: PercentageDisplay = Field(description="Weight today.")
    after: PercentageDisplay = Field(description="Weight once the order fills.")


__all__ = ["OrderLine", "WeightShift"]
