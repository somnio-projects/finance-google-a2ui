"""The published ``simulate_sale`` example, written out (spec 0013 §3).

Its own module, and a **literal** oracle on purpose. Rebuilding the expected
payload from the domain leaves the tool's own wiring unasserted: a summary
that swapped ``shortTermPlDisplay`` with ``longTermPlDisplay`` would invert
the tax split — the whole point of Flow B — while every invariant test stayed
green, because short plus long still equals the total either way.

The figures below were re-derived when the portfolio became equities (spec
0025), and the split was checked by hand rather than copied: selling 75 NVDA
under FIFO takes all 60 shares of the **long** lot, bought at $760, and 15 of
the 30 in the **short** one, bought at $960, against a $1,204.66 price — so
60 x $444.66 = $26,679.60 long and 15 x $244.66 = $3,669.90 short. The larger
figure belongs to the older lot; a swapped wiring would put it under
``shortTermPlDisplay``.

Keep it identical to the example in the spec: OD-9 tells Epic 2 to write the
component schema from that section, so the two drifting apart is a defect in
both.
"""

from collections.abc import Mapping

#: The answer to ``{"symbol": "NVDA", "quantity": "75"}``, in full.
FIFO_SEVENTY_FIVE_NVDA: Mapping[str, object] = {
    "summary": {
        "symbol": "NVDA",
        "lotMethod": "FIFO",
        "priceDisplay": "$1,204.66",
        "quantityDisplay": "75",
        "proceedsDisplay": "$90,349.50",
        "costBasisDisplay": "$60,000.00",
        "realizedPlDisplay": "+$30,349.50",
        "realizedPlPctDisplay": "50.58%",
        "shortTermPlDisplay": "+$3,669.90",
        "longTermPlDisplay": "+$26,679.60",
        "shortTermLots": 1,
        "longTermLots": 1,
        "trend": "up",
    },
    "remaining": {
        "count": 1,
        "quantityDisplay": "15",
        "costBasisDisplay": "$14,400.00",
        "marketValueDisplay": "$18,069.90",
    },
    "lots": [
        {
            "lotId": "lot-nvda-01",
            "acquiredOnDisplay": "2025-09-16",
            "term": "long",
            "quantityDisplay": "60",
            "costBasisDisplay": "$45,600.00",
            "proceedsDisplay": "$72,279.60",
            "gainLossDisplay": "+$26,679.60",
            "trend": "up",
            "fullySold": True,
        },
        {
            "lotId": "lot-nvda-02",
            "acquiredOnDisplay": "2025-09-20",
            "term": "short",
            "quantityDisplay": "15",
            "costBasisDisplay": "$14,400.00",
            "proceedsDisplay": "$18,069.90",
            "gainLossDisplay": "+$3,669.90",
            "trend": "up",
            "fullySold": False,
        },
    ],
}

__all__ = ["FIFO_SEVENTY_FIVE_NVDA"]
