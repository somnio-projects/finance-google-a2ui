"""``portfolio.summary.v1`` — the Home hero as one projection (spec 0026).

This is the shell's half of `Home.dc.html`: everything on that screen that is
not the `HoldingsSummary` catalog component. It is a projection all the same,
because the rule that the client binds and never computes does not stop at
the catalog's edge — a hero total assembled from three requests on the client
would be the arithmetic ADR-K forbids, and a greeting chosen by the device
clock would be the clock read N-13 forbids.

This module is the projection — id, pure ``render``, A2UI adapter, fitness and
``register(...)``; ``summary_payload`` declares what the payload is,
``summary_options`` what may be asked for, ``summary_figures`` writes the
numbers down and ``summary_questions`` holds the words.
"""

from typing import Final

from app.domain.persona import DEMO_ACCOUNT
from app.domain.portfolio import Portfolio
from app.presentation import summary_figures as figures
from app.presentation.displays import money
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Total
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.summary_options import PortfolioSummaryOptions
from app.presentation.summary_payload import (
    SUMMARY,
    TITLE,
    VIEW_ID,
    Account,
    PortfolioSummaryPayload,
)
from app.presentation.summary_questions import (
    MOVERS_TITLE,
    QUESTIONS_TITLE,
    SUGGESTED_QUESTIONS,
)
from app.presentation.surfaces import Surface


def render(
    portfolio: Portfolio, options: PortfolioSummaryOptions
) -> PortfolioSummaryPayload:
    """Map the portfolio onto the Home hero payload.

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the shell binds, every figure already formatted.
    """
    holdings = portfolio.holdings()
    return PortfolioSummaryPayload(
        greeting=figures.greeting_for(portfolio.as_of),
        # The signed-in person when the service named one (spec 0030); the
        # design's persona when a token carries no name to speak of.
        account=Account(
            name=portfolio.owner.name if portfolio.owner else DEMO_ACCOUNT.name,
            initial=portfolio.owner.initial
            if portfolio.owner
            else DEMO_ACCOUNT.initial,
        ),
        badge=DEMO_ACCOUNT.badge,
        total=Total(
            label=TITLE,
            amount=money(
                portfolio.total_market_value(),
                precision=options.precision,
                locale=options.locale,
            ),
        ),
        change=figures.change_over(portfolio, holdings, options),
        spark=figures.spark(portfolio, holdings, options),
        questions_title=QUESTIONS_TITLE,
        questions=SUGGESTED_QUESTIONS,
        movers_title=MOVERS_TITLE,
        movers=figures.movers(options),
    )


def surface(payload: PortfolioSummaryPayload) -> Surface:
    """Map the payload onto the A2UI hero the shell instantiates."""
    return Surface(
        component="PortfolioSummary",
        view=payload.view,
        title=payload.total.label,
        props={
            "greeting": payload.greeting,
            "account": payload.account.model_dump(mode="json"),
            "badge": payload.badge,
            "total": payload.total.model_dump(mode="json"),
            "change": payload.change.model_dump(mode="json"),
            "spark": [point.model_dump(mode="json") for point in payload.spark],
            "questions": [row.model_dump(mode="json") for row in payload.questions],
            "movers": [row.model_dump(mode="json") for row in payload.movers],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Score 1 whenever there is a portfolio to summarise — it always fits."""
    return 1 if portfolio.holdings() else 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=PortfolioSummaryOptions,
        dto=PortfolioSummaryPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["PROJECTION", "VIEW_ID", "render", "surface"]
