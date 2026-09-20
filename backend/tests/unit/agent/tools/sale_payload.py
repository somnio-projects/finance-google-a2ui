"""The published ``simulate_sale`` example, written out (spec 0013 §3).

Its own module, and a **literal** oracle on purpose. Rebuilding the expected
payload from the domain leaves the tool's own wiring unasserted: a summary
that swapped ``shortTermPlDisplay`` with ``longTermPlDisplay`` would invert
the tax split — the whole point of Flow B — while every invariant test stayed
green, because short plus long still equals the total either way.

Keep it identical to the example in the spec: OD-9 tells Epic 2 to write the
component schema from that section, so the two drifting apart is a defect in
both.
"""

from collections.abc import Mapping

#: The answer to ``{"symbol": "BTC", "quantity": "0.5"}``, in full.
FIFO_HALF_BITCOIN: Mapping[str, object] = {
    "summary": {
        "symbol": "BTC",
        "lotMethod": "FIFO",
        "priceDisplay": "$64,250.00",
        "quantityDisplay": "0.5",
        "proceedsDisplay": "$32,125.00",
        "costBasisDisplay": "$22,620.00",
        "realizedPlDisplay": "+$9,505.00",
        "realizedPlPctDisplay": "42.02%",
        "shortTermPlDisplay": "+$580.00",
        "longTermPlDisplay": "+$8,925.00",
        "shortTermLots": 1,
        "longTermLots": 1,
        "trend": "up",
    },
    "remaining": {
        "count": 1,
        "quantityDisplay": "0.1",
        "costBasisDisplay": "$5,700.00",
        "marketValueDisplay": "$6,425.00",
    },
    "lots": [
        {
            "lotId": "lot-btc-01",
            "acquiredOnDisplay": "2025-09-16",
            "term": "long",
            "quantityDisplay": "0.42",
            "costBasisDisplay": "$18,060.00",
            "proceedsDisplay": "$26,985.00",
            "gainLossDisplay": "+$8,925.00",
            "trend": "up",
            "fullySold": True,
        },
        {
            "lotId": "lot-btc-02",
            "acquiredOnDisplay": "2025-09-20",
            "term": "short",
            "quantityDisplay": "0.08",
            "costBasisDisplay": "$4,560.00",
            "proceedsDisplay": "$5,140.00",
            "gainLossDisplay": "+$580.00",
            "trend": "up",
            "fullySold": False,
        },
    ],
}

__all__ = ["FIFO_HALF_BITCOIN"]
