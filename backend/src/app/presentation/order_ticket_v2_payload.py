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
server-side, because a client may not add one to a unit count (N-2).

**There is no total quantity, and there is no value that would be one**
(GGU-122 AC-1, spec 0046 OD-2). The panel used to carry ``impact.units``, the
arithmetic sum of every leg's quantity under the label *Est. shares*: on the
crypto portfolio that is ``0.05 + 1.0 + 16 = 17.05``, a figure of nothing,
sitting beside a money total that is correct and therefore lending it credit.
Units across different assets are not commensurable, so the field is gone
rather than relabelled — the header already states the leg count, and each
``lines[]`` entry carries its own quantity in its own asset.

Nothing here places anything. ``effect`` names the only thing the ticket does,
``disclosure`` says it in words, and the blocked state is a declared field a
client reads rather than a comparison it performs (spec 0018 OD-2, 0031 OD-4).

``controls`` is the same statement made to the one button that looked as
though it disagreed. It is deliberately **not** called ``actions``, which
``contract.py`` reads as the list of things a surface may send back; this one
sends nothing, and its single entry is served ``enabled: false`` with the
reason in words (spec 0050 OD-2).
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.draft_legs import LEGS_PATTERN, MAX_LEGS, MAX_LEGS_TEXT
from app.domain.payoff import Side
from app.presentation.fragments import ProjectionDto
from app.presentation.order_ticket_v2_controls import MAX_CONTROLS, TicketControl

# Re-exported: `Badge`, `Breach` and the two blocks moved out for the file
# budget and are imported from here by everything that was already importing
# them. One home for the names, two files for the bodies.
from app.presentation.order_ticket_v2_impact import (
    Badge,
    Breach,
    OrderConstraints,
    OrderImpact,
)
from app.presentation.order_ticket_v2_lines import OrderLine

VIEW_ID: Final[str] = "order.ticket.v2"
EFFECT: Final[str] = "recalculate"
SUMMARY: Final[str] = (
    "Multi-leg draft order: each leg struck at its reference price with its "
    "weight in the order, the order's impact — total, fees, cash remaining, "
    "the group's weight before and after — and whether the available cash "
    "covers it. Editing a leg re-renders it; it places nothing."
)
DISCLOSURE: Final[str] = (
    "Illustrative draft. This showcase has no broker and no execution: "
    "stepping a leg re-renders these figures, fees are simulated at zero, "
    "and nothing is ever sent, placed or settled."
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
    controls: tuple[TicketControl, ...] = Field(
        max_length=MAX_CONTROLS,
        description=(
            "The buttons the design draws, each with its label and whether it "
            "is live. Not `actions`: this surface sends nothing back."
        ),
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
