"""``payoff.curve.v1`` — what a proposed order makes if the price moves.

Flow C's chart: a profit-and-loss line over a bounded price grid for an order
that does not exist yet, entry and break-even marked. This module is the
projection — id, DTO, pure ``render``, A2UI adapter, fitness and its
``register(...)`` call; ``payoff_order`` declares what may be asked for and
``payoff_figures`` writes the numbers down (spec 0016 OD-5).

**Spot only.** The arithmetic is ``app.domain.payoff_pricing``'s linear
``(price - entry) x quantity``, over a domain with no strike, no expiry and no
volatility, so every payload carries a disclosure and the surface binds it
(spec 0014 OD-8) rather than letting a line imply an option payoff.

The order is **not** portfolio data: it arrives as declared options, and the
portfolio supplies only the reference price at ``as_of`` (spec 0016 OD-1).
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.market import market_asset
from app.domain.payoff_pricing import payoff_curve
from app.domain.portfolio import Portfolio
from app.presentation import payoff_figures as figures
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Annotation, ProjectionDto, Series, Total
from app.presentation.payoff_order import PayoffCurveOptions
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

VIEW_ID: Final[str] = "payoff.curve.v1"
TITLE: Final[str] = "Payoff across a price range"
SUMMARY: Final[str] = (
    "Profit and loss of a proposed buy or sell across a bounded range of "
    "future prices, entry and break-even marked. An illustrative linear spot "
    "payoff, never an options payoff."
)
DISCLOSURE: Final[str] = (
    "Illustrative linear spot payoff on the demo portfolio's simulated "
    "prices: profit or loss is (price - entry) x quantity, with no fees, no "
    "slippage and no financing. There is no strike, no expiry, no implied "
    "volatility and no time decay behind this line. A sell is the mirror of "
    "the position and leaves no position to value."
)
SECTIONS: Final[tuple[str, ...]] = ("totals", "series", "annotations")


class PayoffCurvePayload(ProjectionDto):
    """What a proposed order makes or loses across a range of prices."""

    view: Literal["payoff.curve.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    disclosure: str = Field(
        max_length=400,
        description="What this curve is and is not; shown with the chart.",
        examples=[DISCLOSURE],
    )
    totals: tuple[Total, ...] = Field(
        default=(), description="Entry price, break-even price and notional."
    )
    series: tuple[Series, ...] = Field(
        default=(), description="The profit-and-loss line, ascending by price."
    )
    annotations: tuple[Annotation, ...] = Field(
        default=(), description="Markers shown on the chart, written here."
    )


def render(portfolio: Portfolio, options: PayoffCurveOptions) -> PayoffCurvePayload:
    """Price the proposed order across the requested range (spec 0016 AC-1).

    Args:
        portfolio: The domain result, never fetched here. It supplies the
            reference price at ``as_of`` and nothing else (spec 0016 OD-1).
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.
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
        totals=figures.totals(curve, shape) if "totals" in sections else (),
        series=(figures.line(curve, shape),) if "series" in sections else (),
        annotations=figures.notes(curve, shape) if "annotations" in sections else (),
    )


def surface(payload: PayoffCurvePayload) -> Surface:
    """Map the payload onto the A2UI line chart the genui client instantiates."""
    return Surface(
        component="LineChart",
        view=payload.view,
        title=payload.title,
        props={
            "lines": [row.model_dump(mode="json") for row in payload.series],
            "totals": [row.model_dump(mode="json") for row in payload.totals],
            "markers": [note.model_dump(mode="json") for note in payload.annotations],
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

__all__ = ["DISCLOSURE", "PROJECTION", "SECTIONS", "VIEW_ID", "render", "surface"]
