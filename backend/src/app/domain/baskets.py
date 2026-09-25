"""Turning a vague buying intent into legs (spec 0031, re-based by 0044).

*"Put about $10k into the majors, keep it diversified"* names a theme and an
amount, not a ticker and a unit count. The model must not do the step in
between — choosing weights and dividing dollars by prices is arithmetic, and
the invariant says it never performs any (ADR-K D-5) — so the step lives here,
as a **closed** vocabulary of baskets the tool declares as an enum.

Two kinds of basket. ``majors`` is curated, with the weights the design draws
for its three legs (40 / 35 / 25); it is the crypto reading of the design's
*semiconductors* prompt, and it maps onto the same three legs at the same
weights (spec 0044 OD-8). Every other name is an **ecosystem** of the
taxonomy, split equally across the assets that settle on that chain.

Units are **floored to the asset's own step** (spec 0044 OD-6): "about ten
thousand" is a ceiling a reader trusts, so a floored leg never spends more than
the intent named, and landing on the step is what keeps the ticket's ``+`` and
``-`` on the same grid the leg started on. Flooring to a whole unit was the
equity rule and would floor a $10k intent in BTC to **zero**. A leg that floors
to zero is kept at zero rather than dropped, so the draft still shows the
theme's members and the stepper can bring one in.
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final, Literal

from app.domain.draft_legs import LegRequest
from app.domain.market import MARKET_REFERENCE, market_asset
from app.domain.orders import floor_to_step
from app.domain.taxonomy import Sector

#: What the model may name. Ecosystems are spelled as the taxonomy spells them,
#: so ``Sector(basket)`` resolves every non-curated entry.
Basket = Literal[
    "majors",
    "bitcoin",
    "ethereum",
    "solana",
    "avalanche",
]

#: The design's own legs and weights, from ``FlowC-Assistant.dc.html``, read
#: onto the three largest single names this portfolio can buy.
CURATED: Final[Mapping[str, tuple[tuple[str, Decimal], ...]]] = {
    "majors": (
        ("BTC", Decimal("0.40")),
        ("ETH", Decimal("0.35")),
        ("SOL", Decimal("0.25")),
    ),
}


def basket_weights(basket: Basket) -> tuple[tuple[str, Decimal], ...]:
    """Return the tickers a basket holds and the share of the amount each takes.

    Args:
        basket: A curated theme, or an ecosystem name.

    Returns:
        ``(symbol, weight)`` pairs whose weights sum to one, in the market
        reference's order for an ecosystem and in the design's for a theme.
    """
    curated = CURATED.get(basket)
    if curated is not None:
        return curated
    sector = Sector(basket)
    members = tuple(
        asset.symbol for asset in MARKET_REFERENCE if asset.sector is sector
    )
    weight = Decimal(1) / len(members)
    return tuple((symbol, weight) for symbol in members)


def basket_legs(basket: Basket, amount: Decimal) -> tuple[LegRequest, ...]:
    """Spread ``amount`` over the basket at reference prices, on each step.

    Args:
        basket: Which theme or ecosystem to buy into.
        amount: The dollars the intent named.

    Returns:
        One leg per member, floored to that asset's step, in basket order.
    """
    return tuple(
        LegRequest(
            symbol=symbol,
            quantity=floor_to_step(
                amount * weight / market_asset(symbol).price,
                step=market_asset(symbol).step,
            ),
        )
        for symbol, weight in basket_weights(basket)
    )


__all__ = ["CURATED", "Basket", "basket_legs", "basket_weights"]
