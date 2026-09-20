"""``order.ticket.v1`` — the proposed order, as a bindable, editable ticket.

Flow C's surface and the catalog's only **interactive** component (spec 0018),
and still a pure projection: the fields a person adjusts are this view's own
declared options, published as ``TicketInput`` descriptors carrying the bound
the options model really enforces, so an edit is a re-render over the paths
ADR-K D-11 already has — never an event this module handles (OD-1). It places
nothing: there is no broker and no execution path here, ``effect`` names the
only thing the ticket does, and the surface offers no affordance to the
contrary (OD-2).
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.market import market_asset
from app.domain.orders import order_notional
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import MoneyDisplay, ProjectionDto, Total
from app.presentation.order_sizing import LABELS, OrderTicketOptions
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface
from app.presentation.tickets import (
    QuantityDisplay,
    TicketInput,
    declared_inputs,
    price,
    quantity,
)

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
    name: str = Field(max_length=64, description="Asset name.", examples=["Bitcoin"])
    side: Side = Field(description="Which way the order goes.", examples=["buy"])
    quantity: QuantityDisplay = Field(description="Units the order covers.")
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


def render(portfolio: Portfolio, options: OrderTicketOptions) -> OrderTicketPayload:
    """Render the proposed order and the inputs that change it (0018 AC-2).

    Args:
        portfolio: The domain result. A *proposed* order reads no position
            from it: sufficiency and realised gain are ``simulate_sale``'s
            question (spec 0014 OD-11, 0018 OD-3).
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.
    """
    asset = market_asset(options.symbol)
    units = options.units(asset.price)
    value = order_notional(units, asset.price)
    return OrderTicketPayload(
        title=TITLE,
        symbol=asset.symbol,
        name=asset.name,
        side=options.side,
        quantity=quantity(units, locale=options.locale),
        entry_price=price(asset.price, locale=options.locale),
        notional=Total(label="Order value", amount=options.money(value)),
        inputs=declared_inputs(options, LABELS),
        disclosure=DISCLOSURE,
    )


def surface(payload: OrderTicketPayload) -> Surface:
    """Map the payload onto the A2UI ticket the genui client instantiates.

    The props carry no submit action, no endpoint and no callback: ``effect``
    is the whole contract (0018 OD-2).
    """
    return Surface(
        component="OrderTicket",
        view=payload.view,
        title=payload.title,
        props={
            "symbol": payload.symbol,
            "name": payload.name,
            "side": payload.side,
            "quantity": payload.quantity.model_dump(mode="json"),
            "entryPrice": payload.entry_price.model_dump(mode="json"),
            "notional": payload.notional.model_dump(mode="json"),
            "inputs": [field.model_dump(mode="json") for field in payload.inputs],
            "effect": payload.effect,
            "disclosure": payload.disclosure,
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Score 0 — a ticket answers an intent, never a shape of data (0018 OD-5)."""
    return 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=OrderTicketOptions,
        dto=OrderTicketPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["DISCLOSURE", "EFFECT", "PROJECTION", "VIEW_ID", "render", "surface"]
