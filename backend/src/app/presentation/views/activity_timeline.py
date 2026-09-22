"""``activity.timeline.v1`` — the Activity tab as one projection (spec 0028).

``activity_payload`` declares what the payload is, ``activity_rows`` writes
the ledger down; this module is the projection — id, pure ``render``, A2UI
adapter, fitness and ``register(...)``.
"""

from typing import Final

from app.domain.portfolio import Portfolio
from app.presentation.activity_payload import SUMMARY, VIEW_ID, ActivityTimelinePayload
from app.presentation.activity_rows import ActivityOptions, groups_for
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

#: The selection rule never volunteers a tab's projection: it is asked for by id.
NEVER_SELECTED: Final[int] = 0


def render(portfolio: Portfolio, options: ActivityOptions) -> ActivityTimelinePayload:
    """Map the ledger onto the timeline; ``as_of`` decides what *today* is."""
    return ActivityTimelinePayload(
        kind=options.kind,
        groups=groups_for(
            portfolio.transactions(), as_of=portfolio.as_of.date(), options=options
        ),
    )


def surface(payload: ActivityTimelinePayload) -> Surface:
    """Map the payload onto the A2UI timeline the client instantiates."""
    return Surface(
        component="ActivityTimeline",
        view=payload.view,
        title=payload.title,
        props={
            "note": payload.note,
            "kind": payload.kind,
            "filters": [row.model_dump(mode="json") for row in payload.filters],
            "groups": [row.model_dump(mode="json") for row in payload.groups],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Never volunteered: the tab asks for it by id."""
    del portfolio
    return NEVER_SELECTED


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=ActivityOptions,
        dto=ActivityTimelinePayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["PROJECTION", "VIEW_ID", "render", "surface"]
