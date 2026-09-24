"""How a holding is grouped — asset class and sector (spec 0025 OD-3).

The design's `HoldingsSummary` groups the portfolio two ways and says so in its
own schema: ``"groupBy": "assetClass | sector"``. A grouping the backend cannot
express is a grouping the client would have to invent, which is the numbers
invariant broken by another name — so both vocabularies live here, closed, and
a projection selects between them through a declared option.

Closed rather than free text on purpose. An asset class is the denominator of
every allocation figure on screen; a typo would silently create a fifth slice
that sums to nothing, and no test reading its expectation from the same seed
would notice.

Cash is an asset class like any other. The design lists ``USD · Cash & sweep``
as a row with a market value and a 0.0 % day change, and modelling it as a
special case would put a branch in every consumer of a holding.
"""

from enum import StrEnum


class AssetClass(StrEnum):
    """What kind of thing a holding is, as the design's donut groups them."""

    EQUITIES = "equities"
    BONDS = "bonds"
    CASH = "cash"
    ALTERNATIVES = "alternatives"


class Sector(StrEnum):
    """The economic sector an equity belongs to.

    Only equities carry one. A bond fund, a gold ETF and a settlement balance
    have no sector, and the absence is modelled as ``None`` on the asset rather
    than as an ``OTHER`` bucket that would then be indistinguishable from a
    genuine "Other" equity like a broad-market ETF.
    """

    TECHNOLOGY = "technology"
    FINANCIALS = "financials"
    HEALTHCARE = "healthcare"
    CONSUMER = "consumer"
    ENERGY = "energy"
    OTHER = "other"


#: What each class is called on screen. The client never spells these: a label
#: is a server-written string under N-9, like every other word on a surface.
ASSET_CLASS_LABELS: dict[AssetClass, str] = {
    AssetClass.EQUITIES: "Equities",
    AssetClass.BONDS: "Bonds",
    AssetClass.CASH: "Cash",
    AssetClass.ALTERNATIVES: "Alternatives",
}

#: What each sector is called on screen, for the same reason.
SECTOR_LABELS: dict[Sector, str] = {
    Sector.TECHNOLOGY: "Technology",
    Sector.FINANCIALS: "Financials",
    Sector.HEALTHCARE: "Healthcare",
    Sector.CONSUMER: "Consumer",
    Sector.ENERGY: "Energy",
    Sector.OTHER: "Other",
}

__all__ = [
    "ASSET_CLASS_LABELS",
    "SECTOR_LABELS",
    "AssetClass",
    "Sector",
]
