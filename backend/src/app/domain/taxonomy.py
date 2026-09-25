"""How a holding is grouped — asset class and ecosystem (spec 0044 OD-1, OD-2).

The design's `HoldingsSummary` groups the portfolio two ways and says so in its
own schema: ``"groupBy": "assetClass | sector"``. A grouping the backend cannot
express is a grouping the client would have to invent, which is the numbers
invariant broken by another name — so both vocabularies live here, closed, and
a projection selects between them through a declared option.

Closed rather than free text on purpose. An asset class is the denominator of
every allocation figure on screen; a typo would silently create a sixth slice
that sums to nothing, and no test reading its expectation from the same seed
would notice.

**The portfolio is crypto (spec 0044).** An equity's *economic sector* —
Technology, Energy — says nothing about a token, so the two folds are now
*what kind of asset it is* (`AssetClass`) and *which chain family it settles
on* (`Sector`). The option value stays the word design wrote, ``sector``: the
second fold is still "the correlated-exposure bucket this asset sits in", and
renaming design's own schema word in a data change would break the client, the
catalog snapshot and the design contract for a synonym (OD-2).

The settlement asset is an asset class like any other. The design lists a row
with a market value and a 0.0 % day change, and modelling the stablecoin as a
special case would put a branch in every consumer of a holding — the argument
cash carried here before it, unchanged by the balance now being tokenised.
"""

from enum import StrEnum


class AssetClass(StrEnum):
    """What kind of thing a holding is, as the design's donut groups them."""

    LAYER1 = "layer1"
    LAYER2 = "layer2"
    STABLECOIN = "stablecoin"
    DEFI = "defi"
    INFRASTRUCTURE = "infrastructure"


class Sector(StrEnum):
    """The chain family an asset settles on — the second fold's vocabulary.

    Not every asset has one. A multi-chain stablecoin is natively issued on
    several of these at once, so attributing it to one would be a false
    denominator, and the absence is modelled as ``None`` on the asset rather
    than as an ``OTHER`` bucket that would then be indistinguishable from a
    genuine ecosystem (OD-2).
    """

    BITCOIN = "bitcoin"
    ETHEREUM = "ethereum"
    SOLANA = "solana"
    AVALANCHE = "avalanche"


#: What each class is called on screen. The client never spells these: a label
#: is a server-written string under N-9, like every other word on a surface.
ASSET_CLASS_LABELS: dict[AssetClass, str] = {
    AssetClass.LAYER1: "Layer 1",
    AssetClass.LAYER2: "Layer 2",
    AssetClass.STABLECOIN: "Stablecoins",
    AssetClass.DEFI: "DeFi",
    AssetClass.INFRASTRUCTURE: "Infrastructure",
}

#: What each ecosystem is called on screen, for the same reason.
SECTOR_LABELS: dict[Sector, str] = {
    Sector.BITCOIN: "Bitcoin",
    Sector.ETHEREUM: "Ethereum",
    Sector.SOLANA: "Solana",
    Sector.AVALANCHE: "Avalanche",
}

__all__ = [
    "ASSET_CLASS_LABELS",
    "SECTOR_LABELS",
    "AssetClass",
    "Sector",
]
