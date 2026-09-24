"""Which holdings the Holdings tab's two filters keep (spec 0035 §3.2).

Beside ``positions_rows`` rather than inside it, for the budget and for the
seam: that module knows how a row is *written*, this one knows which rows
there are. Both are pure and neither knows it is being called from a chip.

**What this module deliberately does not touch is the header.** `total`,
`gain` and each row's `weight` stay facts about the whole portfolio while
this narrows the list (spec 0035 OD-4). A filtered total would be a second,
differently-scoped figure on a screen that already shows the real one, and
`weight` would stop meaning *share of the portfolio*.
"""

from collections.abc import Sequence

from app.domain.holdings import Holding
from app.domain.market import market_asset
from app.presentation.positions_payload import ALL_CLASSES, AssetFilter
from app.presentation.search import matches


def in_class(holding: Holding, asset_class: AssetFilter) -> bool:
    """Whether ``holding`` belongs to the requested class; ``all`` keeps it."""
    if asset_class == ALL_CLASSES:
        return True
    return market_asset(holding.symbol).asset_class.value == asset_class


def kept(
    holdings: Sequence[Holding], *, asset_class: AssetFilter, needle: str
) -> list[Holding]:
    """Return the holdings both filters keep, in the order they arrived.

    Args:
        holdings: The portfolio's positions, in seed order.
        asset_class: The chip the caller picked; ``all`` is no filter.
        needle: An already-folded search; empty is no filter.

    Returns:
        A new list; the two filters compose with **and**, and the search
        matches the ticker or the asset's display name (spec 0035 OD-6).
    """
    return [
        holding
        for holding in holdings
        if in_class(holding, asset_class)
        and matches(needle, holding.symbol, holding.name)
    ]


__all__ = ["in_class", "kept"]
