"""How the portfolio is grouped for an allocation donut (spec 0026 OD-2).

`HoldingsSummary`'s own schema says ``"groupBy": "assetClass | sector"``, and
the design draws both. Each grouping is a pure fold over the holdings: value,
what it was worth yesterday, and its share of the whole.

Order is **semantic**, not sorted. The taxonomy's own order is the row order
whatever the sizes; a grouping that re-sorted by value would move the
settlement row around as the market moved, which is not how a reader finds a
row.

The second fold is the **ecosystem** (spec 0044 OD-2), and it is deliberately
not a relabelling of the first: BTC, ETH, SOL and AVAX share one class and no
ecosystem, while ARB, AAVE and LINK share Ethereum across three classes. It
covers only what has an ecosystem, so its weights sum to the attributable
total, not the portfolio's — a multi-chain stablecoin has no single chain to be
in.
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

    key: str = Field(description="Stable identifier of the slice.", examples=["layer1"])
    label: str = Field(description="Words the legend shows.", examples=["Layer 1"])
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
#: And for ecosystems.
SECTOR_ORDER: Final[tuple[str, ...]] = tuple(sector.value for sector in Sector)


def by_asset_class(holdings: Sequence[Holding]) -> tuple[AllocationGroup, ...]:
    """Group every holding by asset class, in the design's order."""

    def keyed(row: Holding) -> tuple[str, str]:
        kind = market_asset(row.symbol).asset_class
        return kind.value, ASSET_CLASS_LABELS[kind]

    return _fold(holdings, keyed, CLASS_ORDER)


def by_sector(holdings: Sequence[Holding]) -> tuple[AllocationGroup, ...]:
    """Group by **ecosystem**; anything without one is left out (OD-2)."""

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
