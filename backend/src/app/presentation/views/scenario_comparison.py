"""``scenario.comparison.v1`` — the same sale, side by side (spec 0017).

Flow B's second surface: one symbol, one quantity, one price, and one column
per lot-selection method, so a reader can see what the method — and only the
method — changes.

``render`` keeps the Protocol's ``(portfolio, options)`` shape and puts the
*scenario* in the declared options, deriving each column through the pure
``simulate_sale``; spec 0017 OD-1 records why, and what that exposes about
ADR-K. The card ranks nothing and recommends nothing (OD-4). Its shapes live
in ``presentation.scenarios``, its options in ``presentation.scenario_options``
and its builders in ``presentation.scenario_build`` (OD-8).
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.market import market_asset
from app.domain.portfolio import Portfolio
from app.domain.sales import simulate_sale
from app.presentation import scenario_build as build
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Annotation, ProjectionDto
from app.presentation.registry import register
from app.presentation.scenario_guidance import GUIDANCE
from app.presentation.scenario_options import ScenarioComparisonOptions, resolve
from app.presentation.scenarios import (
    NOTES,
    SAME,
    ScenarioColumn,
    ScenarioSpread,
    ScenarioSubject,
)
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

VIEW_ID: Final[str] = "scenario.comparison.v1"
TITLE: Final[str] = "Same sale, different lot method"
SUMMARY: Final[str] = (
    "The same proposed sale costed under each lot-selection method, so the "
    "realised result and the short/long split can be compared side by side. "
    "It recommends no method."
)


class ScenarioComparisonPayload(ProjectionDto):
    """One proposed sale, costed under each method the caller asked for."""

    view: Literal["scenario.comparison.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    subject: ScenarioSubject = Field(description="What every column holds fixed.")
    columns: tuple[ScenarioColumn, ...] = Field(
        description="One column per method, in the requested order — never sorted."
    )
    spread: ScenarioSpread = Field(description="The gap between the extremes.")
    notes: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the card, written here."
    )


def render(
    portfolio: Portfolio, options: ScenarioComparisonOptions
) -> ScenarioComparisonPayload:
    """Cost one proposed sale under each requested method (spec 0017 AC-2).

    Args:
        portfolio: The domain data; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.

    Raises:
        ValidationFailedError: When the named position holds no open lots.
        PositionTooSmallError: When the sale is larger than the position — it
            fails every column identically, so there is no card (OD-5).
    """
    symbol, units = resolve(portfolio, options)
    runs = [
        (method, simulate_sale(portfolio, symbol=symbol, quantity=units, method=method))
        for method in options.methods
    ]
    columns = tuple(
        build.column(run, method=method, options=options) for method, run in runs
    )
    gap = build.spread(columns, options=options)
    return ScenarioComparisonPayload(
        title=TITLE,
        subject=build.subject(
            runs[0][1], name=market_asset(symbol).name, options=options
        ),
        columns=columns,
        spread=gap,
        notes=NOTES if gap.differs else (*NOTES, SAME),
    )


def surface(payload: ScenarioComparisonPayload) -> Surface:
    """Map the payload onto the A2UI comparison card the genui client shows."""
    return Surface(
        component="ScenarioComparison",
        view=payload.view,
        title=payload.title,
        props={
            "subject": payload.subject.model_dump(mode="json"),
            "columns": [row.model_dump(mode="json") for row in payload.columns],
            "spread": payload.spread.model_dump(mode="json"),
            "notes": [note.text for note in payload.notes],
        },
    )


def fitness(_portfolio: Portfolio) -> int:
    """Score 0 always: a sale card is never volunteered (spec 0017 OD-6)."""
    return 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=ScenarioComparisonOptions,
        dto=ScenarioComparisonPayload,
        render=render,
        surface=surface,
        fitness=fitness,
        guidance=GUIDANCE,
    )
)

__all__ = ["PROJECTION", "SUMMARY", "TITLE", "VIEW_ID", "render", "surface"]
