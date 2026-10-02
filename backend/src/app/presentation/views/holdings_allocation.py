"""``holdings.allocation.v1`` — the donut, grouped three ways (spec 0005, 0026).

The projection: id, DTO, pure ``render``, A2UI adapter, fitness and
``register(...)``. ``allocation_options`` declares what may be asked for and
``allocation_rows`` turns a grouping into slices (ADR-K D-15). Spec 0026 added
what the design draws and the payload lacked: ``group_by``, a day change on
every row, the count in the donut's hole and the all-time gain under the total.
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.portfolio import Portfolio
from app.presentation.allocation_gain import gain
from app.presentation.allocation_groups import GroupChoice, choices
from app.presentation.allocation_options import HoldingsAllocationOptions
from app.presentation.allocation_rows import (
    CENTER_UNITS,
    GROUPERS,
    TITLES,
    AllocationSlice,
    Center,
    GroupBy,
    rows_for,
)
from app.presentation.displays import money
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import ProjectionDto, Total
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.summary_payload import Change
from app.presentation.surfaces import Surface

VIEW_ID: Final[str] = "holdings.allocation.v1"
SUMMARY: Final[str] = (
    "Allocation of the portfolio's market value — by holding, asset class or "
    "sector — with weight and day change per slice, the count in the donut's "
    "centre, and the all-time gain under the total."
)


class HoldingsAllocationPayload(ProjectionDto):
    """How the portfolio's market value is spread, and how each slice moved."""

    view: Literal["holdings.allocation.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(max_length=120, description="Title the widget shows.")
    group_by: GroupBy = Field(description="Which grouping the slices are.")
    groups: tuple[GroupChoice, ...] = Field(
        description=(
            "Every grouping the `group_by` option declares, in the order the "
            "toggle shows them, with the one this render used marked. The "
            "client draws a segment per entry and sends `value` back as "
            "`group_by`; it never writes the words itself (GGU-145)."
        )
    )
    total: Total = Field(description="Total market value of the portfolio.")
    total_gain: Change | None = Field(
        default=None, description="All-time gain; absent when `headline` is off."
    )
    center: Center = Field(description="What the donut prints in its hole.")
    categories: tuple[AllocationSlice, ...] = Field(
        description="One slice per group, in the design's order, `Other` last."
    )


def render(
    portfolio: Portfolio, options: HoldingsAllocationOptions
) -> HoldingsAllocationPayload:
    """Map the portfolio's holdings onto the allocation payload (spec 0005 AC-4)."""
    holdings = portfolio.holdings()
    slices = rows_for(
        holdings,
        group_by=options.group_by,
        sort=options.sort,
        top_n=options.top_n,
        include_other=options.include_other,
        digits=options.precision,
        locale=options.locale,
    )
    total = portfolio.total_market_value()
    return HoldingsAllocationPayload(
        title=TITLES[options.group_by],
        group_by=options.group_by,
        groups=choices(options.group_by),
        total=Total(
            label="Total market value",
            amount=money(total, precision=options.precision, locale=options.locale),
        ),
        total_gain=gain(portfolio, options) if options.headline else None,
        # The hole counts the groups, not the slices ``top_n`` left to draw.
        center=Center(
            count=str(len(GROUPERS[options.group_by](holdings))),
            unit=CENTER_UNITS[options.group_by],
        ),
        categories=slices,
    )


def surface(payload: HoldingsAllocationPayload) -> Surface:
    """Map the payload onto the A2UI donut the genui client instantiates."""
    gain = payload.total_gain
    return Surface(
        component="HoldingsSummary",
        view=payload.view,
        title=payload.title,
        props={
            "groupBy": payload.group_by,
            "groups": [choice.model_dump(mode="json") for choice in payload.groups],
            "center": payload.center.model_dump(mode="json"),
            "total": payload.total.model_dump(mode="json"),
            "totalGain": None if gain is None else gain.model_dump(mode="json"),
            "slices": [row.model_dump(mode="json") for row in payload.categories],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Score 1 whenever there is anything to allocate — it always fits."""
    return 1 if portfolio.holdings() else 0


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=HoldingsAllocationOptions,
        dto=HoldingsAllocationPayload,
        render=render,
        surface=surface,
        fitness=fitness,
    )
)

__all__ = ["PROJECTION", "VIEW_ID", "render", "surface"]
