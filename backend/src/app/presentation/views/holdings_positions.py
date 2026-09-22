"""``holdings.positions.v1`` — the Holdings tab's position list (spec 0028).

The tab's other card is ``holdings.allocation.v1`` grouped by class or sector
(spec 0026); this projection is the rest of `Holdings.dc.html`: the total with
its all-time gain, and one row per position with the hand-off to the
assistant. ``positions_payload`` declares the DTO, ``positions_rows`` writes
each row down; this module is the projection itself.
"""

from typing import Final

from app.domain.portfolio import Portfolio
from app.presentation import positions_rows as rows
from app.presentation.displays import money
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Total
from app.presentation.positions_payload import (
    SUMMARY,
    TOTAL_LABEL,
    VIEW_ID,
    HoldingsPositionsPayload,
)
from app.presentation.positions_rows import HoldingsPositionsOptions
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

#: The selection rule never volunteers a tab's projection: it is asked for by id.
NEVER_SELECTED: Final[int] = 0


def render(
    portfolio: Portfolio, options: HoldingsPositionsOptions
) -> HoldingsPositionsPayload:
    """Map the portfolio's holdings onto the Holdings tab payload."""
    holdings = portfolio.holdings()
    return HoldingsPositionsPayload(
        total=Total(
            label=TOTAL_LABEL,
            amount=money(
                portfolio.total_market_value(),
                precision=options.precision,
                locale=options.locale,
            ),
        ),
        gain=rows.total_gain(holdings, locale=options.locale),
        positions=tuple(
            rows.position_of(holding, options)
            for holding in rows.ordered(holdings, options.sort)
        ),
    )


def surface(payload: HoldingsPositionsPayload) -> Surface:
    """Map the payload onto the A2UI list the client instantiates."""
    return Surface(
        component="PositionList",
        view=payload.view,
        title=payload.title,
        props={
            "total": payload.total.model_dump(mode="json"),
            "gain": payload.gain.model_dump(mode="json"),
            "askLabel": payload.ask_label,
            "positions": [row.model_dump(mode="json") for row in payload.positions],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Never volunteered: the tab asks for it by id (like the tax-lot table)."""
    del portfolio
    return NEVER_SELECTED


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=HoldingsPositionsOptions,
        dto=HoldingsPositionsPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["PROJECTION", "VIEW_ID", "render", "surface"]
