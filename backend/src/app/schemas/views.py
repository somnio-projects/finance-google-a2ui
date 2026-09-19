"""DTOs of the view catalog and the portfolio-views endpoint (spec 0005 §3).

The envelope is HTTP's; the payloads inside it belong to the presentation
layer, so ``views`` is typed as the projection base and serialised
``SerializeAsAny`` — the concrete member keeps every field it rendered, while
the OpenAPI document shows the precise discriminated union
(``app.presentation.contract``).
"""

from datetime import datetime
from typing import Annotated, Any, Final, Literal

from pydantic import BaseModel, ConfigDict, Field, SerializeAsAny

from app.presentation.fragments import ProjectionDto
from app.presentation.options import Locale, SortOrder

MAX_VIEWS: Final[int] = 4
DEFAULT_VIEW: Final[str] = "holdings.allocation.v1"
CURRENT_PORTFOLIO: Final[str] = "current"
VIEW_ID_PATTERN: Final[str] = r"^[a-z][a-z0-9]*(\.[a-z0-9_]+)+\.v[0-9]{1,3}$"

ViewId = Annotated[str, Field(max_length=64, pattern=VIEW_ID_PATTERN)]
SectionName = Annotated[str, Field(max_length=32, pattern=r"^[a-z_]{1,32}$")]


class ViewQuery(BaseModel):
    """Query parameters of ``GET /v1/portfolios/{portfolio_id}/views``.

    ``extra="forbid"`` is the endpoint's half of ADR-K D-3: a query parameter
    this endpoint does not declare is a 422, not a silently ignored string.
    Every option defaults to ``None`` so only what the caller actually supplied
    is forwarded, and each projection then rejects what it does not declare.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    view: list[ViewId] = Field(
        default_factory=list,
        max_length=MAX_VIEWS,
        description=(
            f"Projection to render; repeat it for up to {MAX_VIEWS} views in "
            "one request. Omit it and the selection rule picks from the data."
        ),
        examples=[["holdings.allocation.v1", "attribution.waterfall.v1"]],
    )
    currency: Literal["USD"] | None = Field(
        default=None, description="Currency of every figure.", examples=["USD"]
    )
    precision: int | None = Field(
        default=None,
        ge=0,
        le=8,
        description="Decimal places for every rendered figure.",
        examples=[2],
    )
    locale: Locale | None = Field(
        default=None, description="Formatting locale.", examples=["en-US"]
    )
    sort: SortOrder | None = Field(
        default=None,
        description="Row order where the view has rows.",
        examples=["label"],
    )
    top_n: int | None = Field(
        default=None,
        ge=1,
        le=20,
        description="Rows to render before the residual bucket.",
        examples=[5],
    )
    include_other: bool | None = Field(
        default=None,
        description="Aggregate everything beyond `top_n` into an `Other` row.",
        examples=[True],
    )
    fields: list[SectionName] | None = Field(
        default=None,
        max_length=8,
        description="Sections of the payload to render; omit for all of them.",
        examples=[["buckets"]],
    )

    def options(self) -> dict[str, Any]:
        """Return only the options the caller actually supplied."""
        return self.model_dump(exclude_none=True, exclude={"view"})


class ViewDescriptor(BaseModel):
    """One entry of the `/v1/views` catalog (ADR-K D-8)."""

    model_config = ConfigDict(frozen=True)

    id: str = Field(
        max_length=64,
        description="Versioned projection id to pass as `?view=`.",
        examples=["holdings.allocation.v1"],
    )
    summary: str = Field(
        max_length=300,
        description="What the projection shows, in one line.",
        examples=["Allocation by holding: market value and weight per symbol."],
    )
    endpoints: list[str] = Field(
        description="The endpoints that serve this projection.",
        examples=[["GET /v1/portfolios/{portfolio_id}/views"]],
    )
    options_schema: dict[str, Any] = Field(
        description="JSON schema of the options this projection declares.",
        examples=[{"properties": {"precision": {"type": "integer"}}}],
    )
    example: dict[str, Any] = Field(
        description="A payload this projection really renders, for the client.",
        examples=[{"view": "holdings.allocation.v1"}],
    )


class PortfolioViewsResponse(BaseModel):
    """Projections rendered for one portfolio, keyed by view id (ADR-K D-17)."""

    model_config = ConfigDict(frozen=True)

    as_of: datetime = Field(
        description="Instant the portfolio was read at, fixed per session.",
        examples=["2026-01-15T12:00:00Z"],
    )
    portfolio_id: str = Field(
        max_length=64,
        description="The portfolio these projections were rendered from.",
        examples=[CURRENT_PORTFOLIO],
    )
    views: dict[str, SerializeAsAny[ProjectionDto]] = Field(
        description="One rendered projection per requested view id."
    )


__all__ = [
    "CURRENT_PORTFOLIO",
    "DEFAULT_VIEW",
    "MAX_VIEWS",
    "VIEW_ID_PATTERN",
    "PortfolioViewsResponse",
    "SectionName",
    "ViewDescriptor",
    "ViewId",
    "ViewQuery",
]
