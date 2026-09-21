"""The rows of ``holdings.allocation.v1``, however the portfolio is grouped.

Split from the view when ``group_by`` arrived (spec 0026 OD-2). The view keeps
its id, options, DTO and adapter; this module turns a grouping into slices and
writes each one down — value, weight, and the day change the design draws on
every legend row.

``AllocationSlice`` extends the shared ``Category``, so a client that bound
the old three fields keeps working and one that binds ``change`` gets it.
"""

from collections.abc import Callable, Sequence
from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.signed_display import signed_percentage_display
from app.domain.allocation import (
    AllocationGroup,
    by_asset_class,
    by_holding,
    by_sector,
)
from app.domain.day_change import Trend, change_ratio, trend_of
from app.domain.holdings import Holding
from app.domain.money import ZERO
from app.presentation.displays import PercentageDisplay, money, percentage
from app.presentation.fragments import Category

GroupBy = Literal["holding", "asset_class", "sector"]

OTHER_KEY: Final[str] = "other"
#: The design prints the day change to one decimal on a legend row.
CHANGE_PRECISION: Final[int] = 1

#: What the donut's centre counts, per grouping (`4 / Classes` on the design).
CENTER_UNITS: Final[dict[str, str]] = {
    "holding": "Holdings",
    "asset_class": "Classes",
    "sector": "Sectors",
}
#: The heading per grouping — the design's card reads *Holdings & allocation*.
TITLES: Final[dict[str, str]] = {
    "holding": "Allocation by holding",
    "asset_class": "Holdings & allocation",
    "sector": "Holdings & allocation",
}
GROUPERS: Final[
    dict[str, Callable[[Sequence[Holding]], tuple[AllocationGroup, ...]]]
] = {
    "holding": by_holding,
    "asset_class": by_asset_class,
    "sector": by_sector,
}
#: Row order for the ungrouped view — a table, so a new order is a new entry.
SORTERS: Final[
    dict[str, Callable[[Sequence[AllocationGroup]], list[AllocationGroup]]]
] = {
    "value_desc": lambda rows: sorted(rows, key=lambda g: (-g.value, g.key)),
    "value_asc": lambda rows: sorted(rows, key=lambda g: (g.value, g.key)),
    "label": lambda rows: sorted(rows, key=lambda g: g.label),
}


class AllocationSlice(Category):
    """A ``Category`` that also says which way it moved today."""

    change: PercentageDisplay = Field(description="Day change, signed.")
    trend: Trend = Field(description="Direction, so the widget picks the glyph.")


class Center(BaseModel):
    """What the donut prints in its hole — a count and what it counts."""

    model_config = ConfigDict(frozen=True)

    count: str = Field(max_length=4, description="How many slices.", examples=["4"])
    unit: str = Field(max_length=16, description="What they are.", examples=["Classes"])


def slice_of(group: AllocationGroup, *, digits: int, locale: str) -> AllocationSlice:
    """Write one group down as a slice."""
    ratio = change_ratio(group.value, group.previous_value)
    return AllocationSlice(
        key=group.key,
        label=group.label,
        value=money(group.value, precision=digits, locale=locale),
        weight=percentage(group.weight, precision=digits, locale=locale),
        change=PercentageDisplay(
            value=ratio,
            display=signed_percentage_display(
                ratio, precision=CHANGE_PRECISION, locale=locale
            ),
        ),
        trend=trend_of(ratio),
    )


def rows_for(
    holdings: Sequence[Holding],
    *,
    group_by: GroupBy,
    sort: str,
    top_n: int,
    include_other: bool,
    digits: int,
    locale: str,
) -> tuple[AllocationSlice, ...]:
    """Group, order and trim the holdings into the slices the donut draws.

    Sorting and the ``top_n`` / ``Other`` residual apply to the **holding**
    grouping only: a class or sector row has a place the reader expects it in,
    and folding *Cash* into *Other* would hide the row every reader looks for.
    """
    groups = list(GROUPERS[group_by](holdings))
    if group_by != "holding":
        return tuple(slice_of(g, digits=digits, locale=locale) for g in groups)
    ordered = SORTERS[sort](groups)
    shown = ordered[:top_n]
    if ordered[top_n:] and include_other:
        shown.append(_other_of(ordered[top_n:]))
    return tuple(slice_of(g, digits=digits, locale=locale) for g in shown)


def _other_of(rest: Sequence[AllocationGroup]) -> AllocationGroup:
    """Fold the groups past ``top_n`` into the one ``Other`` residual."""
    weight: Decimal = sum((g.weight for g in rest), ZERO)
    return AllocationGroup(
        key=OTHER_KEY,
        label="Other",
        value=sum((g.value for g in rest), ZERO),
        previous_value=sum((g.previous_value for g in rest), ZERO),
        weight=weight,
        count=sum(g.count for g in rest),
    )


__all__ = [
    "CENTER_UNITS",
    "GROUPERS",
    "OTHER_KEY",
    "SORTERS",
    "TITLES",
    "AllocationSlice",
    "Center",
    "GroupBy",
    "rows_for",
    "slice_of",
]
