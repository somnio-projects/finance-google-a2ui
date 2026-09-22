"""What a draft order shifts: a group's weight before and after (spec 0031).

The design's *Portfolio weight · Semis 6.2% → 8.3%* row. The portfolio's
total is the denominator on both sides — a buy turns cash into the group and
a sell turns the group back into cash, so the whole is unchanged and only the
group's share moves. A statement about the portfolio, so it lives beside
``draft_impact`` rather than in the presenter that prints it (ADR-K D-6).

*Semis* is not a sector this taxonomy has (spec 0031 OD-5): an equity is
reported under its **sector**, and anything without one — a bond fund, gold,
cash — under its **asset class**, so no leg is silently left out of the panel.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from decimal import Decimal

from app.domain.draft_impact import PricedLeg
from app.domain.market import MarketAsset, market_asset
from app.domain.money import ZERO
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio
from app.domain.taxonomy import ASSET_CLASS_LABELS, SECTOR_LABELS


@dataclass(frozen=True, slots=True)
class WeightShift:
    """One group's share of the portfolio before and after the order."""

    key: str
    label: str
    before: Decimal
    after: Decimal


def group_of(asset: MarketAsset) -> tuple[str, str]:
    """Return the key and label an asset's weight is reported under."""
    if asset.sector is not None:
        return asset.sector.value, SECTOR_LABELS[asset.sector]
    return asset.asset_class.value, ASSET_CLASS_LABELS[asset.asset_class]


def _held_by_group(portfolio: Portfolio) -> dict[str, Decimal]:
    """Sum what the portfolio holds today, per group."""
    held: dict[str, Decimal] = {}
    for row in portfolio.holdings():
        key, _ = group_of(market_asset(row.symbol))
        held[key] = held.get(key, ZERO) + row.market_value
    return held


def _ordered_by_group(legs: Sequence[PricedLeg]) -> dict[str, tuple[str, Decimal]]:
    """Sum what the order buys or sells, per group, in first-leg order."""
    ordered: dict[str, tuple[str, Decimal]] = {}
    for leg in legs:
        key, label = group_of(market_asset(leg.symbol))
        _, so_far = ordered.get(key, (label, ZERO))
        ordered[key] = (label, so_far + leg.notional)
    return ordered


def weight_shifts(
    portfolio: Portfolio, legs: Sequence[PricedLeg], side: Side
) -> tuple[WeightShift, ...]:
    """Return each group the legs touch, weighed before and after the order.

    Args:
        portfolio: Whose holdings set the weights.
        legs: The priced legs of the draft.
        side: A buy adds the group's notional; a sell removes it.

    Returns:
        One shift per group, in the order the first leg of each arrives. An
        empty portfolio has no shares to report and yields zeros rather than
        dividing by them.
    """
    total = portfolio.total_market_value()
    held = _held_by_group(portfolio)
    sign = 1 if side == "buy" else -1
    return tuple(
        WeightShift(
            key=key,
            label=label,
            before=held.get(key, ZERO) / total if total else ZERO,
            after=(held.get(key, ZERO) + sign * value) / total if total else ZERO,
        )
        for key, (label, value) in _ordered_by_group(legs).items()
    )


__all__ = ["WeightShift", "group_of", "weight_shifts"]
