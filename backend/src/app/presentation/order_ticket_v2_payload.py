"""The payload of ``order.ticket.v2`` — a multi-leg draft and its impact (spec 0031).

Two fields carry the same option under two names, and the distinction is the
reason this module has a docstring. ``legs`` is the **option echo**: the exact
string a caller sent, named after the option so the generated contract reports
it editable and a client can send it back unchanged (spec 0019 OD-3,
`.claude/rules/backend/presentation.md` §4). ``lines[]`` are the **rendered
legs**: struck, weighed and formatted — an output of the render, like ``v1``'s
``quantity``, and not a value anyone sends back.

The stepper is where the two meet, and ``order_ticket_v2_lines`` holds it:
every line carries the whole ``legs`` value its ``+`` and ``-`` send, written
server-side, because a client may not add one to a share count (N-2).

Nothing here places anything. ``effect`` names the only thing the ticket does,
``disclosure`` says it in words, and the blocked state is a declared field a
client reads rather than a comparison it performs (spec 0018 OD-2, 0031 OD-4).
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.draft_legs import LEGS_PATTERN, MAX_LEGS, MAX_LEGS_TEXT
from app.domain.payoff import Side
from app.presentation.fragments import MoneyDisplay, ProjectionDto, Total
from app.presentation.order_ticket_v2_lines import OrderLine, UnitTotal, WeightShift

VIEW_ID: Final[str] = "order.ticket.v2"
EFFECT: Final[str] = "recalculate"
SUMMARY: Final[str] = (
    "Multi-leg draft order: each leg struck at its reference price with its "
    "share of the order, the order's impact — total, shares, fees, cash "
    "remaining, the sector's weight before and after — and whether the "
    "available cash covers it. Editing a leg re-renders it; it places nothing."
)
DISCLOSURE: Final[str] = (
    "Illustrative draft. This showcase has no broker and no execution: "
    "stepping a leg re-renders these figures, fees are simulated at zero, "
    "and nothing is ever sent, placed or settled."
)

Breach = Literal["none", "over_cash"]
Badge = Literal["editable", "blocked"]


class OrderImpact(BaseModel):
    """The design's *Order impact* panel, every figure pre-formatted."""

    model_config = ConfigDict(frozen=True)

    total: Total = Field(description="What the whole order is worth.")
    units: UnitTotal = Field(description="Shares across every leg.")
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


class OrderTicketV2Payload(ProjectionDto):
    """A multi-leg draft order: its legs, its impact, and what blocks it."""

    view: Literal["order.ticket.v2"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120,
        description="Heading: kind, side and leg count, written here.",
        examples=["Draft order · Buy · 3 legs"],
    )
    badge: Badge = Field(
        description="The header pill: `editable`, or `blocked` on a breach.",
        examples=["editable"],
    )
    side: Side = Field(description="Which way every leg goes.", examples=["buy"])
    legs: str = Field(
        max_length=MAX_LEGS_TEXT,
        pattern=LEGS_PATTERN,
        description="The `legs` option as sent, ready to be sent back unchanged.",
        examples=["BTC:3,ETH:2,SOL:14"],
    )
    lines: tuple[OrderLine, ...] = Field(
        max_length=MAX_LEGS,
        description="The legs, struck and weighed, in the order asked.",
    )
    impact: OrderImpact = Field(description="What the order does, pre-formatted.")
    constraints: OrderConstraints = Field(description="The bound and any breach.")
    disclosure: str = Field(
        max_length=300,
        examples=[DISCLOSURE],
        description="What this draft is and is not, in words the client shows.",
    )
    effect: Literal["recalculate"] = Field(
        default=EFFECT,
        examples=[EFFECT],
        description="The only thing stepping a leg does; nothing is placed.",
    )


__all__ = [
    "DISCLOSURE",
    "EFFECT",
    "SUMMARY",
    "VIEW_ID",
    "Badge",
    "Breach",
    "OrderConstraints",
    "OrderImpact",
    "OrderTicketV2Payload",
]
