"""What a multi-leg draft order does to the portfolio (spec 0031).

The design's *Order impact* panel — total, estimated shares, fees, cash
remaining — is a set of financial statements, and a statement belongs to the
domain rather than to the presenter that prints it or the tool that reads it
aloud (ADR-K D-6). Both of those format what this module states; neither
computes. The panel's last row, a sector's weight before and after, is
``app.domain.draft_weights``: split off for the file budget along the seam
that was already there — what the order costs, apart from what it shifts.

Pure: prices come from the market reference, cash and holdings from the
portfolio passed in, and nothing here rounds (ADR-E D-3). Fees are zero and
say so — the design captions them *sim*, and a fee schedule this showcase
does not have is not one it should imagine.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from decimal import Decimal

from app.domain.draft_legs import LegRequest
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.orders import order_notional
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio
from app.domain.taxonomy import AssetClass


@dataclass(frozen=True, slots=True)
class PricedLeg:
    """One leg struck at the reference price, with its share of the order."""

    symbol: str
    name: str
    price: Decimal
    quantity: Decimal
    notional: Decimal
    weight: Decimal


@dataclass(frozen=True, slots=True)
class DraftImpact:
    """The order's consequences, every figure exact."""

    legs: tuple[PricedLeg, ...]
    total: Decimal
    units: Decimal
    fees: Decimal
    cash_available: Decimal
    cash_after: Decimal
    shortfall: Decimal


def price_legs(requests: Sequence[LegRequest]) -> tuple[PricedLeg, ...]:
    """Strike every leg at its reference price and weigh it in the order.

    A draft with no value — every leg at zero shares — weighs every leg at
    zero rather than dividing by nothing.
    """
    struck = [(market_asset(leg.symbol), Decimal(leg.quantity)) for leg in requests]
    notionals = [order_notional(quantity, asset.price) for asset, quantity in struck]
    total = sum(notionals, ZERO)
    return tuple(
        PricedLeg(
            symbol=asset.symbol,
            name=asset.name,
            price=asset.price,
            quantity=quantity,
            notional=notional,
            weight=notional / total if total else ZERO,
        )
        for (asset, quantity), notional in zip(struck, notionals, strict=True)
    )


def cash_available(portfolio: Portfolio) -> Decimal:
    """Return what the portfolio holds as cash — the bound a buy is checked against."""
    return sum(
        (
            row.market_value
            for row in portfolio.holdings()
            if market_asset(row.symbol).asset_class is AssetClass.CASH
        ),
        ZERO,
    )


def draft_impact(
    portfolio: Portfolio, requests: Sequence[LegRequest], side: Side
) -> DraftImpact:
    """State what the draft costs, buys and leaves.

    Args:
        portfolio: Whose cash the order draws on.
        requests: The legs as asked for.
        side: A buy spends cash and may exceed it; a sell raises cash and is
            never blocked here — whether the shares exist to sell is
            ``simulate_sale``'s question (spec 0018 OD-3).

    Returns:
        The priced legs and the panel's figures. ``shortfall`` is positive
        only for a buy the available cash cannot cover.
    """
    legs = price_legs(requests)
    total = sum((leg.notional for leg in legs), ZERO)
    cash = cash_available(portfolio)
    cash_after = cash - total if side == "buy" else cash + total
    shortfall = -cash_after if cash_after < ZERO else ZERO
    return DraftImpact(
        legs=legs,
        total=total,
        units=sum((leg.quantity for leg in legs), ZERO),
        fees=ZERO,
        cash_available=cash,
        cash_after=cash_after,
        shortfall=shortfall,
    )


__all__ = [
    "DraftImpact",
    "PricedLeg",
    "cash_available",
    "draft_impact",
    "price_legs",
]
