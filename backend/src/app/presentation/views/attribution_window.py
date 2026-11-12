"""``attribution.window.v1`` — what moved the portfolio over a window.

The projection: options model, pure ``render``, A2UI adapter, fitness and its
``register(...)`` call. The DTO lives in ``presentation.window_payload`` and
the builders in ``presentation.window_walk``, the seam
``attribution_waterfall`` already draws.

It answers what ``compute_attribution`` computes; ``window_payload`` records
why this is a new id, and why only today's walk declares the drill.
"""

from datetime import timedelta
from typing import Final

from pydantic import Field

from app.domain.attribution import attribute_window
from app.domain.portfolio import Portfolio
from app.presentation import options as opt
from app.presentation import window_walk as walk
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Total
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface
from app.presentation.window_payload import (
    DEFAULT_WINDOW,
    END_LABEL,
    SECTIONS,
    START_LABEL,
    SUMMARY,
    TITLE_PREFIX,
    VIEW_ID,
    WINDOW_DAYS,
    WINDOW_WORDS,
    AttributionWindowPayload,
    window_actions,
)

#: Never volunteered by the selection rule: a window is asked for, not guessed.
NEVER_SELECTED: Final[int] = 0


class AttributionWindowOptions(opt.DisplayOptions, opt.FieldSelection):
    """Declared knobs of ``attribution.window.v1``; nothing else is accepted."""

    window: str = Field(
        default=DEFAULT_WINDOW,
        pattern="^(1d|7d|30d)$",
        description=(
            "How far back the walk looks. A closed set, not a free-form "
            "period: an unknown value is a 422, never a best-effort guess."
        ),
        examples=["1d", "7d", "30d"],
    )


def render(
    portfolio: Portfolio, options: AttributionWindowOptions
) -> AttributionWindowPayload:
    """Walk the portfolio's move over ``options.window``, holding by holding.

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.
    """
    sections = options.selected(SECTIONS)
    result = attribute_window(
        portfolio, window=timedelta(days=WINDOW_DAYS[options.window])
    )
    rows = result.contributions
    period = WINDOW_WORDS[options.window]
    steps = (
        walk.buckets(rows, start=result.start_value, options=options)
        if "buckets" in sections
        else ()
    )
    said = (
        walk.notes(rows, result.change, period, options)
        if "annotations" in sections
        else ()
    )
    return AttributionWindowPayload(
        title=f"{TITLE_PREFIX} {period}",
        window=options.window,  # pyright: ignore[reportArgumentType]
        period=period,
        start=Total(label=START_LABEL, amount=options.money(result.start_value)),
        end=Total(label=END_LABEL, amount=options.money(result.end_value)),
        net=walk.net_of(
            start=result.start_value, end=result.end_value, options=options
        ),
        buckets=steps,
        annotations=said,
        actions=window_actions(options.window),
    )


def surface(payload: AttributionWindowPayload) -> Surface:
    """Map the payload onto the all-time walk's A2UI waterfall: same widget."""
    return Surface(
        component="AttributionWaterfall",
        view=payload.view,
        title=payload.title,
        props={
            "start": payload.start.model_dump(mode="json"),
            "end": payload.end.model_dump(mode="json"),
            "net": payload.net.model_dump(mode="json"),
            "window": payload.window,
            "period": payload.period,
            "steps": [step.model_dump(mode="json") for step in payload.buckets],
            "notes": [note.text for note in payload.annotations],
            "actions": [ref.model_dump(mode="json") for ref in payload.actions],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Never volunteered by the selection rule; it is asked for by id."""
    del portfolio
    return NEVER_SELECTED


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=AttributionWindowOptions,
        dto=AttributionWindowPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = [
    "NEVER_SELECTED",
    "PROJECTION",
    "VIEW_ID",
    "AttributionWindowOptions",
    "AttributionWindowPayload",
    "render",
    "surface",
]
