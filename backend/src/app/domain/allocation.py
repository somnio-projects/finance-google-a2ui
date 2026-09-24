"""How the portfolio is grouped for an allocation donut (spec 0026 OD-2).

`HoldingsSummary`'s own schema says ``"groupBy": "assetClass | sector"``, and
the design draws both — four classes on the Home page, six sectors on the
catalog page. Each grouping is a pure fold over the holdings: value, what it
was worth yesterday, and its share of the whole.

Order is **semantic**, not sorted. The design draws Equities, Bonds, Cash,
Alternatives in that order whatever their sizes, and sectors likewise; a
grouping that re-sorted by value would move Cash around as the market moved,
which is not how a reader finds a row.

Sectors are a breakdown of **equities**, so the six sector weights sum to the
equities total, not the portfolio's — a bond fund has no sector to be in.
"""

from collections.abc import Callable, Sequence
from decimal import Decimal
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import previous_value
from app.domain.holdings import Holding
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.taxonomy import ASSET_CLASS_LABELS, SECTOR_LABELS, AssetClass, Sector


class AllocationGroup(BaseModel):
    """One slice of an allocation: what it is worth, was worth, and weighs."""

    model_config = ConfigDict(frozen=True)

    key: str = Field(
        description="Stable identifier of the slice.", examples=["equities"]
    )
    label: str = Field(description="Words the legend shows.", examples=["Equities"])
    value: Decimal = Field(ge=0, description="Market value today.")
    previous_value: Decimal = Field(ge=0, description="Market value yesterday.")
    weight: Decimal = Field(ge=0, le=1, description="Share of the grouping's total.")
    count: int = Field(ge=1, description="How many holdings the slice folds.")


def _fold(
    holdings: Sequence[Holding],
    keyed: Callable[[Holding], tuple[str, str] | None],
    order: Sequence[str],
) -> tuple[AllocationGroup, ...]:
    """Sum ``holdings`` into groups named by ``keyed``, in ``order``."""
    values: dict[str, Decimal] = {}
    previous: dict[str, Decimal] = {}
    counts: dict[str, int] = {}
    labels: dict[str, str] = {}
    for row in holdings:
        named = keyed(row)
        if named is None:
            continue
        key, label = named
        labels[key] = label
        values[key] = values.get(key, ZERO) + row.market_value
        previous[key] = previous.get(key, ZERO) + previous_value(row)
        counts[key] = counts.get(key, 0) + 1
    total = sum(values.values(), ZERO)
    return tuple(
        AllocationGroup(
            key=key,
            label=labels[key],
            value=values[key],
            previous_value=previous[key],
            weight=values[key] / total,
            count=counts[key],
        )
        for key in order
        if key in values
    )


#: The design's row order for classes, whatever their sizes.
CLASS_ORDER: Final[tuple[str, ...]] = tuple(kind.value for kind in AssetClass)
#: And for sectors.
SECTOR_ORDER: Final[tuple[str, ...]] = tuple(sector.value for sector in Sector)


def by_asset_class(holdings: Sequence[Holding]) -> tuple[AllocationGroup, ...]:
    """Group every holding by asset class, in the design's order."""

    def keyed(row: Holding) -> tuple[str, str]:
        kind = market_asset(row.symbol).asset_class
        return kind.value, ASSET_CLASS_LABELS[kind]

    return _fold(holdings, keyed, CLASS_ORDER)


def by_sector(holdings: Sequence[Holding]) -> tuple[AllocationGroup, ...]:
    """Group the **equities** by sector; anything without a sector is left out."""

    def keyed(row: Holding) -> tuple[str, str] | None:
        sector = market_asset(row.symbol).sector
        return None if sector is None else (sector.value, SECTOR_LABELS[sector])

    return _fold(holdings, keyed, SECTOR_ORDER)


def by_holding(holdings: Sequence[Holding]) -> tuple[AllocationGroup, ...]:
    """One group per holding, in the portfolio's own order — the ungrouped view."""
    return _fold(
        holdings,
        lambda row: (row.symbol, row.name),
        [row.symbol for row in holdings],
    )


__all__ = [
    "CLASS_ORDER",
    "SECTOR_ORDER",
    "AllocationGroup",
    "by_asset_class",
    "by_holding",
    "by_sector",
]
