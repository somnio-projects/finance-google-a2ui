"""``payoff.curve.v1`` — what a proposed order makes if the price moves.

Flow C's chart: a profit-and-loss line over a bounded price grid for an order
that does not exist yet, entry and break-even marked. This module is the
projection — id, pure ``render``, A2UI adapter, fitness and its
``register(...)`` call; ``payoff_payload`` declares what the payload is,
``payoff_order`` what may be asked for, ``payoff_figures`` writes the numbers
down and ``payoff_markers`` places the two reference lines (spec 0016 OD-5,
spec 0024 §4).

**Spot only, and that is settled.** The arithmetic is
``app.domain.payoff_pricing``'s linear ``(price - entry) x quantity``, over a
domain with no strike, no expiry and no volatility. Spec 0024 §3 ruled that it
stays that way: an options payoff needs a position this portfolio does not
hold, and drawing one would put a kinked curve beside a disclosure denying it
on the same screen. Every payload carries that disclosure and the surface
binds it (spec 0014 OD-8).

The order is **not** portfolio data: it arrives as declared options, and the
portfolio supplies only the reference price at ``as_of`` (spec 0016 OD-1).
"""

from typing import Final

from app.domain.market import market_asset
from app.domain.payoff_pricing import payoff_curve
from app.domain.portfolio import Portfolio
from app.presentation import payoff_axis as axis
from app.presentation import payoff_figures as figures
from app.presentation import payoff_markers as marks
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.payoff_order import PayoffCurveOptions
from app.presentation.payoff_payload import (
    DISCLOSURE,
    SECTIONS,
    SUMMARY,
    TITLE,
    VIEW_ID,
    PayoffCurvePayload,
)
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface


def render(portfolio: Portfolio, options: PayoffCurveOptions) -> PayoffCurvePayload:
    """Price the proposed order across the requested range (spec 0016 AC-1).

    Args:
        portfolio: The domain result, never fetched here. It supplies the
            reference price at ``as_of`` and nothing else (spec 0016 OD-1).
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted. The
        markers are built unconditionally — ``fields`` may trim the totals,
        the line or the annotations, but never the two coordinates a widget
        would otherwise have to find by reading a label (spec 0024 §4).
    """
    sections = options.selected(SECTIONS)
    asset = market_asset(options.symbol)
    entry_price = portfolio.price(asset.symbol)
    curve = payoff_curve(
        symbol=asset.symbol,
        name=asset.name,
        entry_price=entry_price,
        quantity=options.quantity(entry_price),
        side=options.side,
        range_pct=options.range_pct,
        steps=options.steps,
    )
    shape = figures.Shape(
        places=figures.price_places(step=curve.price_step, entry=entry_price),
        precision=options.precision,
        locale=options.locale,
    )
    return PayoffCurvePayload(
        title=f"{TITLE}: {options.side} {asset.name}",
        disclosure=DISCLOSURE,
        markers=marks.markers(curve, shape),
        value_ticks=axis.value_axis(curve, shape),
        zones=axis.zones(),
        totals=figures.totals(curve, shape) if "totals" in sections else (),
        series=(figures.line(curve, shape),) if "series" in sections else (),
        annotations=figures.notes(curve, shape) if "annotations" in sections else (),
    )


def surface(payload: PayoffCurvePayload) -> Surface:
    """Map the payload onto the A2UI line chart the genui client instantiates.

    ``markers`` is the keyed block; the free-text callouts travel under
    ``annotations``, which is what they are. Before spec 0024 this adapter
    published the callouts *as* ``markers``, so the one prop a widget would
    reach for to place a line held four labelled sentences instead.
    """
    return Surface(
        component="RiskPayoffChart",
        view=payload.view,
        title=payload.title,
        props={
            "lines": [row.model_dump(mode="json") for row in payload.series],
            "totals": [row.model_dump(mode="json") for row in payload.totals],
            "markers": payload.markers.model_dump(mode="json"),
            "valueTicks": [
                tick.model_dump(mode="json") for tick in payload.value_ticks
            ],
            "zones": payload.zones.model_dump(mode="json"),
            "annotations": [
                note.model_dump(mode="json") for note in payload.annotations
            ],
            "disclosure": payload.disclosure,
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Return 0: nothing a portfolio already holds asks for a payoff curve.

    Never auto-selected, then — the selection rule ignores a zero score, and
    this chart answers a question about a **proposed** order (spec 0016 OD-2).
    """
    return 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=PayoffCurveOptions,
        dto=PayoffCurvePayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = [
    "DISCLOSURE",
    "PROJECTION",
    "SECTIONS",
    "TITLE",
    "VIEW_ID",
    "PayoffCurvePayload",
    "render",
    "surface",
]
