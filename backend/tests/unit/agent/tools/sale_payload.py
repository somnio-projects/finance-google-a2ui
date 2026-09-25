"""The published ``simulate_sale`` example, written out (spec 0013 §3).

Its own module, and a **literal** oracle on purpose. Rebuilding the expected
payload from the domain leaves the tool's own wiring unasserted: a summary
that swapped ``shortTermPlDisplay`` with ``longTermPlDisplay`` would invert
the tax split — the whole point of Flow B — while every invariant test stayed
green, because short plus long still equals the total either way.

The figures were re-derived when the portfolio became crypto (spec 0044), and
the split was checked by hand rather than copied: selling **0.75 BTC** under
FIFO takes all 0.25 of the **long** lot, bought at $36,000, and 0.50 of the
1.85 in the **short** one, bought at $42,468, against a $64,250 price — so
0.25 x $28,250 = $7,062.50 long and 0.50 x $21,782 = $10,891.00 short.

**The larger figure now belongs to the newer, short lot**, because spec 0044
sized the long lot small on purpose so the design's own $20k question spans
both terms. That is the opposite of the equities seed, where the older lot was
the bigger one — so this oracle still catches a swapped wiring, but a reader
must not infer the mapping from which figure is larger.

Keep it identical to the example in the spec: OD-9 tells Epic 2 to write the
component schema from that section, so the two drifting apart is a defect in
both.
"""

from collections.abc import Mapping

#: The answer to ``{"symbol": "BTC", "quantity": "0.75"}``, in full.
FIFO_THREE_QUARTERS_BTC: Mapping[str, object] = {
    "summary": {
        "symbol": "BTC",
        "lotMethod": "FIFO",
        "priceDisplay": "$64,250.00",
        "quantityDisplay": "0.75",
        "proceedsDisplay": "$48,187.50",
        "costBasisDisplay": "$30,234.00",
        "realizedPlDisplay": "+$17,953.50",
        "realizedPlPctDisplay": "59.38%",
        "shortTermPlDisplay": "+$10,891.00",
        "longTermPlDisplay": "+$7,062.50",
        "shortTermLots": 1,
        "longTermLots": 1,
        "trend": "up",
    },
    "remaining": {
        "count": 1,
        "quantityDisplay": "1.35",
        "costBasisDisplay": "$57,331.80",
        "marketValueDisplay": "$86,737.50",
    },
    "lots": [
        {
            "lotId": "lot-btc-01",
            "acquiredOnDisplay": "2025-09-16",
            "term": "long",
            "quantityDisplay": "0.25",
            "costBasisDisplay": "$9,000.00",
            "proceedsDisplay": "$16,062.50",
            "gainLossDisplay": "+$7,062.50",
            "trend": "up",
            "fullySold": True,
        },
        {
            "lotId": "lot-btc-02",
            "acquiredOnDisplay": "2025-09-20",
            "term": "short",
            "quantityDisplay": "0.5",
            "costBasisDisplay": "$21,234.00",
            "proceedsDisplay": "$32,125.00",
            "gainLossDisplay": "+$10,891.00",
            "trend": "up",
            "fullySold": False,
        },
    ],
}

__all__ = ["FIFO_THREE_QUARTERS_BTC"]
