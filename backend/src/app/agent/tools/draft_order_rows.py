"""Display shaping for ``draft_order`` (spec 0031).

Every function here is pure and returns nothing but strings, so "did a raw
number escape into the payload?" is a question about this file alone — the
shape ``payoff_rows`` set. The keys mirror ``order.ticket.v2``'s payload, so a
reader comparing what the model said with what the surface shows finds the
same names on both sides.

It registers no tool: ``load_tools()`` imports it and nothing happens, which is
the cost of keeping a tool's helper beside the tool instead of in a shared file
(spec 0006 AC-7).
"""

from collections.abc import Mapping, Sequence
from typing import Final

from app.core.display import (
    money_display,
    percentage_display,
    price_display,
    quantity_display,
)
from app.domain.draft_impact import DraftImpact, PricedLeg
from app.domain.draft_weights import WeightShift
from app.domain.money import ZERO

#: Shipped in every payload, not only in the tool description: whatever the
#: model says around the numbers, the surface can state what they are not.
DISCLOSURE: Final[str] = (
    "Illustrative draft on the demo portfolio's simulated prices: whole "
    "shares at the reference price, fees simulated at zero, nothing placed, "
    "sent or settled. The user edits the legs on the ticket; nothing is "
    "confirmed in prose."
)
OVER_CASH: Final[str] = "Exceeds available cash — reduce order by {shortfall}."


def line(leg: PricedLeg) -> Mapping[str, str]:
    """Describe one leg for the model to read aloud."""
    return {
        "symbol": leg.symbol,
        "name": leg.name,
        "quantityDisplay": quantity_display(leg.quantity, trim=True),
        "priceDisplay": price_display(leg.price),
        "notionalDisplay": money_display(leg.notional),
        "weightDisplay": percentage_display(leg.weight),
    }


def impact_block(
    impact: DraftImpact, shifts: Sequence[WeightShift]
) -> Mapping[str, object]:
    """Describe the order's consequences, every figure formatted."""
    return {
        "totalDisplay": money_display(impact.total),
        "unitsDisplay": quantity_display(impact.units, trim=True),
        "feesDisplay": money_display(impact.fees),
        "cashRemainingDisplay": money_display(impact.cash_after),
        "weightShifts": [
            {
                "label": shift.label,
                "beforeDisplay": percentage_display(shift.before),
                "afterDisplay": percentage_display(shift.after),
            }
            for shift in shifts
        ],
    }


def constraints_block(impact: DraftImpact) -> Mapping[str, object]:
    """Describe the cash bound and whether the draft breached it."""
    blocked = impact.shortfall > ZERO
    shortfall = money_display(impact.shortfall) if blocked else None
    return {
        "maxCashDisplay": money_display(impact.cash_available),
        "breach": "over_cash" if blocked else "none",
        "shortfallDisplay": shortfall,
        "message": None if shortfall is None else OVER_CASH.format(shortfall=shortfall),
    }


__all__ = ["DISCLOSURE", "OVER_CASH", "constraints_block", "impact_block", "line"]
