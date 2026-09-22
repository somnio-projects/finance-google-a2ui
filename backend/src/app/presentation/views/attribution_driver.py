"""``attribution.driver.v1`` — one driver of the day, in detail (spec 0032).

The card Flow A composes when a waterfall bar is tapped. ``driver_payload``
declares the DTO, ``driver_figures`` writes it down from ``app.domain.driver``;
this module is the projection itself: options, ``render``, the A2UI adapter,
fitness and its ``register(...)`` call.
"""

from typing import Final

from pydantic import Field

from app.core.errors import ValidationFailedError
from app.domain.driver import driver_detail
from app.domain.portfolio import Portfolio
from app.domain.symbols import Symbol
from app.presentation.driver_figures import payload_for
from app.presentation.driver_payload import SUMMARY, VIEW_ID, DriverDetailPayload
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.options import DisplayOptions
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

#: The selection rule never volunteers this card: a tap, or the agent's
#: ``driver_detail`` tool, asks for it by id with the symbol (0028 OD-1).
NEVER_SELECTED: Final[int] = 0
#: The design's D2 state drills into NVDA, so the documented example does too.
DEFAULT_SYMBOL: Final[str] = "NVDA"


class DriverDetailOptions(DisplayOptions):
    """The display knobs, and the one thing this card is about: the symbol.

    ``symbol`` is a payload field of the same name, so the contract reports
    it editable and it round-trips (presentation.md §4): re-rendering with
    another symbol is how the same card describes another bar.
    """

    symbol: Symbol = Field(
        default=DEFAULT_SYMBOL,
        description="The holding to describe, from the market reference.",
        examples=["NVDA"],
    )


def render(portfolio: Portfolio, options: DriverDetailOptions) -> DriverDetailPayload:
    """Describe what one holding did to the portfolio today.

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the card binds, every figure already formatted.

    Raises:
        ValidationFailedError: When the portfolio holds no such position. A
            symbol the reference knows but the portfolio does not hold is a
            valid option with no card behind it — a 422 names it, the way an
            unknown ``fields`` section is named, rather than an empty card.
    """
    detail = driver_detail(portfolio, options.symbol)
    if detail is None:
        msg = f"{options.symbol} is not held, so there is no contribution to detail"
        raise ValidationFailedError(msg)
    return payload_for(detail, options)


def surface(payload: DriverDetailPayload) -> Surface:
    """Map the payload onto the A2UI card the client instantiates."""
    return Surface(
        component="DriverDetail",
        view=payload.view,
        title=payload.name,
        props={
            "symbol": payload.symbol,
            "name": payload.name,
            "caption": payload.caption,
            "contribution": payload.contribution.model_dump(mode="json"),
            "trend": payload.trend,
            "priceMove": payload.price_move.model_dump(mode="json"),
            "shares": payload.shares.model_dump(mode="json"),
            "dayShare": payload.day_share.model_dump(mode="json"),
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Never volunteered: a tap or the tool asks for it by id."""
    del portfolio
    return NEVER_SELECTED


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=DriverDetailOptions,
        dto=DriverDetailPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = [
    "DEFAULT_SYMBOL",
    "PROJECTION",
    "VIEW_ID",
    "DriverDetailOptions",
    "fitness",
    "render",
    "surface",
]
