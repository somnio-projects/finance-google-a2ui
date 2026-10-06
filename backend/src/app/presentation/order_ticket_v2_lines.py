"""The fragments of one rendered leg of ``order.ticket.v2`` (spec 0031).

Split from ``order_ticket_v2_payload`` for the file budget, along the seam
that was already there: what one **leg** carries, apart from what the
**ticket** carries. Not promoted to ``fragments.py``: ADR-K D-16 promotes a
primitive when a second consumer needs it, and a stepper has one.

``stops`` and ``position`` are the **slider**; ``increment`` and
``decrement`` are the stepper. The design draws both, a slider is continuous
and this contract is not, so the track is quantised: every stop is a whole
``legs`` value written by ``domain.draft_ladder`` (spec 0050 OD-1).

**They are two granularities of one quantity, not one ladder.** A stepper tap
moves by the asset's own step; the slider's stride is that step coarsened
until the ladder fits its bound, so an ``increment`` is generally not a stop
of the track beside it. What holds instead is the invariant that matters: the
ladder is aligned to the **current** value, so whatever either control sends,
the render it produces puts the thumb on the new number. The stepper stays
because it is the fine, keyboard-reachable control. A client may not add one to a
unit count (N-2), so each is the whole ``legs`` option value the tap sends,
written here from the same parser and bound the options model enforces. A
``null`` means the move would leave the published bound, and the control is
disabled rather than sending a value the backend refuses (spec 0031 OD-3).
"""

from pydantic import BaseModel, ConfigDict, Field

from app.domain.draft_ladder import MAX_LADDER, POSITION_PATTERN
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
    entry: str = Field(
        max_length=MAX_LEGS_TEXT,
        description=(
            "The `legs` value with this leg's units left as `{units}`. The "
            "client puts the quantity a person typed there verbatim — no "
            "parsing, no rounding — and re-renders with the result, which "
            "the options model judges like any other `legs` value (spec "
            "0054); an invalid entry is the usual 422."
        ),
        examples=["BTC:{units},ETH:1.0,SOL:16"],
    )
    stops: tuple[str, ...] = Field(
        max_length=MAX_LADDER,
        description=(
            "Every `legs` value this leg's slider can land on, ascending by "
            "this leg's units and always including the value on screen. A "
            "drag picks one and re-renders; the client interpolates nothing. "
            "A single stop means there is no mix to move — a one-leg ticket's "
            "weight is the whole order — and the client draws no slider."
        ),
        examples=[["BTC:0.0,ETH:1.0,SOL:16", "BTC:0.06,ETH:1.0,SOL:16"]],
    )
    position: str = Field(
        pattern=POSITION_PATTERN,
        description=(
            "Index into `stops` of the value this line is rendered at, as a "
            "decimal string. A number reaches this client only as a string "
            "— `text()` refuses a JSON number and `geometry()` parses a "
            "decimal string (ADR-E D-5, ADR-L D-14) — and a thumb's index is "
            "a position on a track, which is what that seam is for."
        ),
        examples=["1"],
    )


class WeightShift(Labelled):
    """A group's share of the portfolio before and after the order."""

    key: str = Field(max_length=32, description="Group id.", examples=["technology"])
    before: PercentageDisplay = Field(description="Weight today.")
    after: PercentageDisplay = Field(description="Weight once the order fills.")


__all__ = ["OrderLine", "WeightShift"]
