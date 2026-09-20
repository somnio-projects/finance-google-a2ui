"""DTOs of the batch render resource, `POST /v1/view-renders` (ADR-K D-18).

Repeating `?view=` on one portfolio read already batches projections of the
**same** resource (D-17). This is the heterogeneous case: several views, each
over the portfolio it names, in one round trip.

The shape that matters is the **per-entry status**. A batch whose response is
one status for everything makes the client choose between losing three good
widgets because the fourth asked for an unknown view, and retrying entries one
at a time — which is the round trip the batch existed to remove. So every
entry carries either a payload or an RFC 9457 problem of its own, and the
batch itself succeeds as long as it was well formed.
"""

from datetime import datetime
from typing import Any, Final

from pydantic import BaseModel, ConfigDict, Field, SerializeAsAny

from app.presentation.fragments import ProjectionDto
from app.schemas.problem import ProblemDetails
from app.schemas.views import CURRENT_PORTFOLIO, PORTFOLIO_ID_PATTERN, ViewId

#: Documented cap. Each entry costs one portfolio read and one pure render, so
#: the bound exists to keep a single request's work predictable, not because
#: rendering is expensive.
MAX_RENDERS: Final[int] = 8
#: Upper bound on option keys per entry. The projection's own options model
#: rejects anything it does not declare; this only stops an unbounded object
#: reaching it (ADR-K D-3).
MAX_OPTIONS: Final[int] = 16


class ViewRenderRequest(BaseModel):
    """One entry of a batch: which projection, over which portfolio, how."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    view: ViewId = Field(
        description="Registered projection id to render, from `GET /v1/views`.",
        examples=["attribution.waterfall.v1"],
    )
    portfolio_id: str = Field(
        default=CURRENT_PORTFOLIO,
        max_length=64,
        pattern=PORTFOLIO_ID_PATTERN,
        description=(
            "Portfolio to render it over. Only the well-known `current` "
            "exists today: it resolves to the authenticated caller's own."
        ),
        examples=[CURRENT_PORTFOLIO],
    )
    options: dict[str, Any] = Field(
        default_factory=dict,
        max_length=MAX_OPTIONS,
        description=(
            "Declared options for that projection; anything it does not "
            "declare makes this entry a 422 without affecting the others."
        ),
        examples=[{"precision": 2, "top_n": 5}],
    )


class ViewRenderBatch(BaseModel):
    """The batch a client creates — several renders, one round trip."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    renders: list[ViewRenderRequest] = Field(
        min_length=1,
        max_length=MAX_RENDERS,
        description=(
            f"The entries to render, in order; at most {MAX_RENDERS}. The "
            "response answers one result per entry, in the same order."
        ),
        examples=[
            [
                {"view": "holdings.allocation.v1", "portfolio_id": "current"},
                {
                    "view": "attribution.waterfall.v1",
                    "portfolio_id": "current",
                    "options": {"precision": 2},
                },
            ]
        ],
    )


class ViewRenderResult(BaseModel):
    """One entry's outcome: its own status, and a payload or a problem."""

    model_config = ConfigDict(frozen=True)

    status: int = Field(
        ge=200,
        le=599,
        description=(
            "Status this entry alone answers with: 200 rendered, 404 unknown "
            "view or portfolio, 422 a rejected option."
        ),
        examples=[200],
    )
    view: str = Field(
        max_length=64,
        description="The projection id this entry asked for, echoed.",
        examples=["holdings.allocation.v1"],
    )
    portfolio_id: str = Field(
        max_length=64,
        description="The portfolio this entry asked for, echoed.",
        examples=[CURRENT_PORTFOLIO],
    )
    as_of: datetime | None = Field(
        default=None,
        description="Instant the portfolio was read at; absent when it failed.",
        examples=["2026-01-15T12:00:00Z"],
    )
    payload: SerializeAsAny[ProjectionDto] | None = Field(
        default=None,
        description="The rendered projection, discriminated by `view`.",
        examples=[{"view": "holdings.allocation.v1"}],
    )
    error: ProblemDetails | None = Field(
        default=None,
        description="Why this entry failed, as a problem document; else absent.",
        examples=[None],
    )


class ViewRenderBatchResult(BaseModel):
    """Every entry's outcome, in the order the batch listed them."""

    model_config = ConfigDict(frozen=True)

    results: list[ViewRenderResult] = Field(
        description="One result per requested entry, in request order.",
        examples=[[{"status": 200, "view": "holdings.allocation.v1"}]],
    )


__all__ = [
    "MAX_OPTIONS",
    "MAX_RENDERS",
    "ViewRenderBatch",
    "ViewRenderBatchResult",
    "ViewRenderRequest",
    "ViewRenderResult",
]
