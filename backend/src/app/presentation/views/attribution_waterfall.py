"""``attribution.waterfall.v1`` — unrealised P/L, walked (spec 0005 AC-5).

One module holds everything this chart is: id, options model, DTO, pure
``render``, A2UI adapter, fitness and its ``register(...)`` call — the same
shape as every other view, so the next one is a copy (ADR-K D-15).
"""

from typing import Final, Literal

from pydantic import Field

from app.actions.declared import SurfaceActionRef, declared_action
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.domain.portfolio import Portfolio
from app.presentation import options as opt
from app.presentation.attribution_walk import buckets, notes
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Annotation, Bucket, ProjectionDto, Total
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

VIEW_ID: Final[str] = "attribution.waterfall.v1"
TITLE: Final[str] = "Unrealised P/L attribution"
SUMMARY: Final[str] = (
    "Unrealised profit and loss walked from cost basis to market value, one "
    "bucket per holding, biggest move first."
)
SECTIONS: Final[tuple[str, ...]] = ("buckets", "annotations")

#: The one action this surface offers (GGU-31, spec 0022 §3.4). Derived from
#: the action's own arguments schema, so the published bound *is* the enforced
#: one — never a second copy written down beside it.
DRILL_REF: Final[SurfaceActionRef] = declared_action(DRILL)


class AttributionWaterfallOptions(opt.DisplayOptions, opt.FieldSelection):
    """Declared knobs of ``attribution.waterfall.v1``; nothing else is accepted."""


class AttributionWaterfallPayload(ProjectionDto):
    """The walk from what the portfolio cost to what it is worth today."""

    view: Literal["attribution.waterfall.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    start: Total = Field(description="Where the walk starts: total cost basis.")
    end: Total = Field(description="Where the walk ends: total market value.")
    buckets: tuple[Bucket, ...] = Field(
        default=(), description="One step per holding, biggest absolute move first."
    )
    annotations: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the chart, written here."
    )
    actions: tuple[SurfaceActionRef, ...] = Field(
        default=(),
        description=(
            "What tapping this surface may send back: a registered action id "
            "and the bounded argument it takes. Nothing else is accepted."
        ),
    )


def render(
    portfolio: Portfolio, options: AttributionWaterfallOptions
) -> AttributionWaterfallPayload:
    """Walk cost basis to market value, holding by holding (spec 0005 AC-5).

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.
    """
    sections = options.selected(SECTIONS)
    rows = sorted(portfolio.holdings(), key=lambda h: (-abs(h.unrealized_pl), h.symbol))
    cost = portfolio.total_cost_basis()
    value = portfolio.total_market_value()
    walk = buckets(rows, start=cost, options=options) if "buckets" in sections else ()
    net = portfolio.total_unrealized_pl()
    said = notes(rows, net, options) if "annotations" in sections else ()
    return AttributionWaterfallPayload(
        title=TITLE,
        start=Total(label="Cost basis", amount=options.money(cost)),
        end=Total(label="Market value", amount=options.money(value)),
        buckets=walk,
        annotations=said,
        actions=(DRILL_REF,),
    )


def surface(payload: AttributionWaterfallPayload) -> Surface:
    """Map the payload onto the A2UI waterfall the genui client instantiates."""
    return Surface(
        component="WaterfallChart",
        view=payload.view,
        title=payload.title,
        props={
            "start": payload.start.model_dump(mode="json"),
            "end": payload.end.model_dump(mode="json"),
            "steps": [step.model_dump(mode="json") for step in payload.buckets],
            "notes": [note.text for note in payload.annotations],
            "actions": [ref.model_dump(mode="json") for ref in payload.actions],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Score 2 when the portfolio holds a winner **and** a loser to explain."""
    return 2 if len({row.unrealized_pl > 0 for row in portfolio.holdings()}) > 1 else 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=AttributionWaterfallOptions,
        dto=AttributionWaterfallPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["DRILL_REF", "PROJECTION", "SECTIONS", "VIEW_ID", "render", "surface"]
