"""Turning a vague buying intent into legs (spec 0031).

*"Put about $10k into semiconductors, keep it diversified"* names a theme and
an amount, not a ticker and a share count. The model must not do the step in
between — choosing weights and dividing dollars by prices is arithmetic, and
the invariant says it never performs any (ADR-K D-5) — so the step lives here,
as a **closed** vocabulary of baskets the tool declares as an enum.

Two kinds of basket. ``semiconductors`` is curated, with the weights the design
draws for its three legs (40 / 35 / 25). Every other name is a sector of the
taxonomy, split equally across its single-name equities: a fund is a basket
already and would double-count the theme.

Shares are **floored**: "about ten thousand" is a ceiling a reader trusts, and
a floored leg never spends more than the intent named. A leg that floors to
zero is kept at zero rather than dropped, so the draft still shows the theme's
members and the stepper can bring one in.
"""

from collections.abc import Mapping
from decimal import ROUND_FLOOR, Decimal
from typing import Final, Literal

from app.domain.draft_legs import LegRequest
from app.domain.market import MARKET_REFERENCE, market_asset
from app.domain.taxonomy import Sector

#: What the model may name. Sectors are spelled as the taxonomy spells them,
#: so ``Sector(basket)`` resolves every non-curated entry.
Basket = Literal[
    "semiconductors",
    "technology",
    "financials",
    "healthcare",
    "consumer",
    "energy",
]

#: The design's own legs and weights, from ``FlowC-Assistant.dc.html``.
CURATED: Final[Mapping[str, tuple[tuple[str, Decimal], ...]]] = {
    "semiconductors": (
        ("NVDA", Decimal("0.40")),
        ("AVGO", Decimal("0.35")),
        ("AMD", Decimal("0.25")),
    ),
}


def basket_weights(basket: Basket) -> tuple[tuple[str, Decimal], ...]:
    """Return the tickers a basket holds and the share of the amount each takes.

    Args:
        basket: A curated theme, or a sector name.

    Returns:
        ``(symbol, weight)`` pairs whose weights sum to one, in the market
        reference's order for a sector and in the design's for a theme.
    """
    curated = CURATED.get(basket)
    if curated is not None:
        return curated
    sector = Sector(basket)
    members = tuple(
        asset.symbol
        for asset in MARKET_REFERENCE
        if asset.sector is sector and not asset.is_fund
    )
    weight = Decimal(1) / len(members)
    return tuple((symbol, weight) for symbol in members)


def basket_legs(basket: Basket, amount: Decimal) -> tuple[LegRequest, ...]:
    """Spread ``amount`` over the basket in whole shares at reference prices.

    Args:
        basket: Which theme or sector to buy into.
        amount: The dollars the intent named.

    Returns:
        One leg per member, floored to whole shares, in basket order.
    """
    return tuple(
        LegRequest(
            symbol=symbol,
            quantity=int(
                (amount * weight / market_asset(symbol).price).to_integral_value(
                    rounding=ROUND_FLOOR
                )
            ),
        )
        for symbol, weight in basket_weights(basket)
    )


__all__ = ["CURATED", "Basket", "basket_legs", "basket_weights"]
