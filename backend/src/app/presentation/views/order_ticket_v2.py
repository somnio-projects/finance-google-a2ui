"""``order.ticket.v2`` — a multi-leg draft order with its live impact (spec 0031).

Flow C's surface as the design draws it: three legs with a stepper each, and
an *Order impact* panel that recomputes on every edit. Still a pure projection
(ADR-K D-6): an edit is the caller re-sending the ``legs`` option with one
number moved, and the number it moves to is one this payload wrote — a client
may not add one to a share count (N-2), so every line carries the value its
``+`` and ``-`` send. It places nothing: ``effect`` names the only thing the
ticket does and the A2UI props carry no way to submit (spec 0018 OD-2).

``order.ticket.v1`` is untouched beside it. The design's multi-leg ticket is
not a backwards-compatible addition to a single-leg payload (spec 0024), so it
is a second contract with a second component name — `MultiLegOrderTicket`,
spec 0031 OD-1 — and the two are served side by side.
"""

from typing import Final

from app.domain.draft_impact import draft_impact
from app.domain.draft_weights import weight_shifts
from app.domain.portfolio import Portfolio
from app.presentation import order_ticket_v2_build as build
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.order_ticket_v2_controls import CONTROLS
from app.presentation.order_ticket_v2_guidance import GUIDANCE
from app.presentation.order_ticket_v2_options import OrderTicketV2Options
from app.presentation.order_ticket_v2_payload import (
    DISCLOSURE,
    EFFECT,
    SUMMARY,
    VIEW_ID,
    OrderTicketV2Payload,
)
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

#: The A2UI component the client registers against. Not the design's
#: ``OrderTicket``: that name is held by ``v1`` and this ticket may not move
#: it (spec 0031 OD-1). Re-pointing is a client-breaking rename filed there.
COMPONENT: Final[str] = "MultiLegOrderTicket"


def render(portfolio: Portfolio, options: OrderTicketV2Options) -> OrderTicketV2Payload:
    """Render the draft, its impact and whether the cash covers it (0031 AC-2).

    Args:
        portfolio: The domain result: its cash is the bound a buy is checked
            against and its holdings set the weights the order shifts.
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure formatted, the ``legs``
        option echoed under its own name and every leg carrying the option
        value its stepper sends (spec 0031 OD-3).
    """
    requests = options.requests()
    impact = draft_impact(portfolio, requests, options.side)
    shifts = weight_shifts(portfolio, impact.legs, options.side)
    breach = build.breach_of(impact)
    return OrderTicketV2Payload(
        title=build.title(requests, options.side),
        badge=build.badge_of(breach),
        side=options.side,
        legs=options.legs,
        lines=build.lines(portfolio, impact, requests, options),
        impact=build.impact_block(impact, shifts, options),
        constraints=build.constraints_block(impact, options),
        controls=CONTROLS,
        disclosure=DISCLOSURE,
    )


def surface(payload: OrderTicketV2Payload) -> Surface:
    """Map the payload onto the A2UI component the client instantiates.

    The props carry no submit action, no endpoint and no callback: ``effect``
    is the whole contract (spec 0018 OD-2, 0031 OD-4). ``controls`` is not an
    exception — it describes a button the design draws, serves it
    ``enabled: false``, and says why (spec 0050 OD-2).
    """
    return Surface(
        component=COMPONENT,
        view=payload.view,
        title=payload.title,
        props={
            "badge": payload.badge,
            "side": payload.side,
            "legs": payload.legs,
            "lines": [line.model_dump(mode="json") for line in payload.lines],
            "impact": payload.impact.model_dump(mode="json"),
            "constraints": payload.constraints.model_dump(mode="json"),
            "controls": [c.model_dump(mode="json") for c in payload.controls],
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
        options=OrderTicketV2Options,
        dto=OrderTicketV2Payload,
        render=render,
        surface=surface,
        fitness=fitness,
        guidance=GUIDANCE,
    )
)

__all__ = [
    "COMPONENT",
    "DISCLOSURE",
    "EFFECT",
    "PROJECTION",
    "VIEW_ID",
    "OrderTicketV2Options",
    "OrderTicketV2Payload",
    "render",
    "surface",
]
