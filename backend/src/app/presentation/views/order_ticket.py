"""``order.ticket.v1`` — the proposed order, as a bindable, editable ticket.

Flow C's surface and the catalog's only **interactive** component (spec 0018),
and still a pure projection: the fields a person adjusts are this view's own
declared options, published as ``TicketInput`` descriptors carrying the bound
the options model really enforces, so an edit is a re-render over the paths
ADR-K D-11 already has — never an event this module handles (OD-1). It places
nothing: there is no broker and no execution path here, ``effect`` names the
only thing the ticket does, and the surface offers no affordance to the
contrary (OD-2).

The payload itself lives in ``app.presentation.order_payload``, which is where
the naming rule that makes an option *visibly* editable is written down.
"""

from typing import Final

from app.domain.market import market_asset
from app.domain.orders import order_notional
from app.domain.portfolio import Portfolio
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Total
from app.presentation.order_payload import (
    DISCLOSURE,
    EFFECT,
    SUMMARY,
    TITLE,
    VIEW_ID,
    OrderTicketPayload,
)
from app.presentation.order_sizing import LABELS, OrderTicketOptions
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface
from app.presentation.tickets import declared_inputs, price, quantity


def render(portfolio: Portfolio, options: OrderTicketOptions) -> OrderTicketPayload:
    """Render the proposed order and the inputs that change it (0018 AC-2).

    Args:
        portfolio: The domain result. A *proposed* order reads no position
            from it: sufficiency and realised gain are ``simulate_sale``'s
            question (spec 0014 OD-11, 0018 OD-3).
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted and every
        editable option carried under its own name (spec 0019 OD-3).
    """
    asset = market_asset(options.symbol)
    units = options.units(asset.price)
    value = order_notional(units, asset.price)
    return OrderTicketPayload(
        title=TITLE,
        symbol=asset.symbol,
        name=asset.name,
        side=options.side,
        size=options.size,
        size_in=options.size_in,
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
            "size": payload.size,
            "sizeIn": payload.size_in,
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

__all__ = [
    "DISCLOSURE",
    "EFFECT",
    "PROJECTION",
    "VIEW_ID",
    "OrderTicketPayload",
    "render",
    "surface",
]
