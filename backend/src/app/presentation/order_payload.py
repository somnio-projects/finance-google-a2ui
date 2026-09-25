"""The payload of ``order.ticket.v1``, and what it names an input.

Its own module for the reason ``order_sizing`` is one: the view is over the
file budget, and this is the seam that was already there — *what is rendered*
apart from *what a caller may ask for*.

**Every editable option has a payload field of exactly its own name** (spec
0019 OD-3, `.claude/rules/backend/presentation.md` §4). That naming is the
interactivity declaration the generated contract reads, so ``size`` and
``size_in`` are carried here beside ``symbol`` and ``side`` — the four options
``LABELS`` offers as controls, and no others.

``quantity`` is **not** one of them, and the distinction is the whole reason
this file has a docstring. It is the *derived* unit count
``OrderTicketOptions.units`` computes: under ``size_in="usd"`` it is the size
divided by the entry price (ADR-K D-5), so it is an output of the render, not
a value a caller sends back. Naming it after ``size`` would make the contract
advertise a display pair as an input and invite a client to round-trip a
number the options model does not accept — a published bound the backend does
not enforce, which is the defect `.claude/rules/backend/testing.md` records.
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.payoff import Side
from app.presentation.fragments import MoneyDisplay, ProjectionDto, Total
from app.presentation.order_sizing import SIZE_PATTERN, SizeUnit
from app.presentation.ticket_displays import QuantityDisplay
from app.presentation.tickets import TicketInput

VIEW_ID: Final[str] = "order.ticket.v1"
TITLE: Final[str] = "Proposed order"
EFFECT: Final[str] = "recalculate"
SUMMARY: Final[str] = (
    "Order ticket: a proposed buy or sell with its units, entry price and "
    "notional, plus the bounded inputs that re-render it. It places nothing."
)
DISCLOSURE: Final[str] = (
    "Illustrative ticket. This showcase has no broker and no execution: "
    "changing a field re-renders these figures, and nothing is ever sent, "
    "placed or settled."
)


class OrderTicketPayload(ProjectionDto):
    """A proposed order: what it costs, and what a person may change about it."""

    view: Literal["order.ticket.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(max_length=120, description="Heading shown.", examples=[TITLE])
    symbol: str = Field(max_length=10, description="Ticker ordered.", examples=["BTC"])
    name: str = Field(
        max_length=64, description="Asset name.", examples=["NVIDIA Corp"]
    )
    side: Side = Field(description="Which way the order goes.", examples=["buy"])
    size: str = Field(
        max_length=32,
        pattern=SIZE_PATTERN,
        description=(
            "How big the order is, as asked for — the `size` option's current "
            "value, ready to be sent back unchanged."
        ),
        examples=["0.25"],
    )
    size_in: SizeUnit = Field(
        description="What `size` counts: units of the asset, or US dollars.",
        examples=["units"],
    )
    quantity: QuantityDisplay = Field(
        description=(
            "Units the order covers. **Derived, not editable**: a dollar size "
            "is divided by the entry price server-side, so this is an output "
            "of `size` and `size_in`, never a value sent back."
        )
    )
    entry_price: MoneyDisplay = Field(description="Price a unit is struck at.")
    notional: Total = Field(description="What the order is worth at that price.")
    inputs: tuple[TicketInput, ...] = Field(
        description=(
            "The editable options, each with the bound the backend enforces "
            "when it comes back. Send one with the same `view` to re-render."
        )
    )
    effect: Literal["recalculate"] = Field(
        default=EFFECT,
        description="All this ticket does; no order placement exists here.",
        examples=[EFFECT],
    )
    disclosure: str = Field(
        max_length=300,
        description="What the ticket is and is not, in words.",
        examples=[DISCLOSURE],
    )


__all__ = [
    "DISCLOSURE",
    "EFFECT",
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "OrderTicketPayload",
]
