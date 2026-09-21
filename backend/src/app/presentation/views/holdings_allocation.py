"""``holdings.allocation.v1`` — allocation by holding (spec 0005 AC-4).

One module holds everything this chart is: id, options model, DTO, pure
``render``, A2UI adapter, fitness for the selection rule and its
``register(...)`` call. Nothing else in the tree knows it exists, which is what
makes the next chart one new file (ADR-K D-15).
"""

from collections.abc import Callable, Sequence
from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.domain.holdings import Holding
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Category, ProjectionDto, Total, money, percentage
from app.presentation.options import (
    CurrencyOptions,
    PrecisionOptions,
    SortOptions,
    TopNOptions,
)
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface

VIEW_ID: Final[str] = "holdings.allocation.v1"
TITLE: Final[str] = "Allocation by holding"
SUMMARY: Final[str] = (
    "Allocation by holding: market value and portfolio weight per symbol, "
    "with a residual Other bucket for everything beyond top_n."
)
OTHER_KEY: Final[str] = "other"

#: Row order per ``sort`` option — a table, so a new order is a new entry.
SORTERS: Final[dict[str, Callable[[Sequence[Holding]], list[Holding]]]] = {
    "value_desc": lambda rows: sorted(rows, key=lambda h: (-h.market_value, h.symbol)),
    "value_asc": lambda rows: sorted(rows, key=lambda h: (h.market_value, h.symbol)),
    "label": lambda rows: sorted(rows, key=lambda h: h.name),
}


class HoldingsAllocationOptions(
    CurrencyOptions, PrecisionOptions, SortOptions, TopNOptions
):
    """Declared knobs of ``holdings.allocation.v1``; nothing else is accepted."""


class HoldingsAllocationPayload(ProjectionDto):
    """How the portfolio's market value is spread across its holdings."""

    view: Literal["holdings.allocation.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    total: Total = Field(description="Total market value of the portfolio.")
    categories: tuple[Category, ...] = Field(
        description="One slice per holding, in the requested order, `Other` last."
    )


def _slice(
    key: str, label: str, value: Decimal, weight: Decimal, digits: int
) -> Category:
    """Build one slice from an already-summed market value and weight."""
    return Category(
        key=key,
        label=label,
        value=money(value, precision=digits),
        weight=percentage(weight, precision=digits),
    )


def render(
    portfolio: Portfolio, options: HoldingsAllocationOptions
) -> HoldingsAllocationPayload:
    """Map the portfolio's holdings onto the allocation payload (spec 0005 AC-4).

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options for this render.

    Returns:
        The payload the widget binds, every figure already formatted.
    """
    digits = options.precision
    rows = SORTERS[options.sort](portfolio.holdings())
    rest = rows[options.top_n :]
    slices = [
        _slice(row.symbol, row.name, row.market_value, row.weight, digits)
        for row in rows[: options.top_n]
    ]
    if rest and options.include_other:
        value = sum((row.market_value for row in rest), ZERO)
        weight = sum((row.weight for row in rest), ZERO)
        slices.append(_slice(OTHER_KEY, "Other", value, weight, digits))
    total = portfolio.total_market_value()
    return HoldingsAllocationPayload(
        title=TITLE,
        total=Total(label="Total market value", amount=money(total, precision=digits)),
        categories=tuple(slices),
    )


def surface(payload: HoldingsAllocationPayload) -> Surface:
    """Map the payload onto the A2UI donut the genui client instantiates."""
    return Surface(
        component="AllocationSummary",
        view=payload.view,
        title=payload.title,
        props={
            "center": payload.total.model_dump(mode="json"),
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

__all__ = ["OTHER_KEY", "PROJECTION", "SORTERS", "VIEW_ID", "render", "surface"]
