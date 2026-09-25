"""The curated demo portfolio's **open lots**, as data (spec 0044, 0003 OD-2).

The ledger that produced them lives in ``seed_ledger.py``: the two tables
outgrew one module when spec 0035 took the ledger to 48 rows, and they are
split along the seam that was already there — what is *held* against what
*happened*.

Code-defined rather than a JSON fixture: a file that never changes at runtime
does not deserve its own loader, its own validation path and its own failure
modes. Every number is a **string**, parsed to ``Decimal`` by the entities in
``app.domain.seed`` (ADR-E D-5), and quantities are written to **eight
decimals** because that is the precision a crypto position is held to — the
column declares the domain's scale instead of leaving a reader to infer it
(spec 0044 AC-2).

Lots are positioned by ``days_before`` the injected ``as_of`` instead of by
absolute date, so the demo cases hold whatever day the demo runs:

* **BTC** carries the tax-lot story: lots straddling the 1-year boundary, one
  at 367 days (long) and one at 363 days (short, two days inside it), both at
  a gain, so the short/long split has a figure on each side. The long lot is
  deliberately the **smaller** one — 0.25 against 1.85 — so that the design's
  own Flow B question, *"if I sell $20k of BTC"*, consumes all of it and part
  of the second under FIFO and the table has a row in each term. Sized the
  other way round, the flow the demo actually runs would show one.
* **ETH** carries the lot-selection story: two lots at two very different unit
  costs — 1,850 and 4,175 — so FIFO, LIFO and HIFO cannot agree about what a
  sale consumes, and the newer lot is *under water* while the older is far
  ahead (spec 0013 AC-5).
* **SOL**, **LINK** and **ARB** carry the attribution story: losers standing
  next to BTC's and ETH's gains, so the waterfall has bars of both signs.
* **USDC** is the settlement balance — one unit is one dollar, so quantity is
  the balance and it can never show a gain.

**The figures reconcile, and two of them are the design's (spec 0044 OD-4).**
Quantity times price equals each position's market value to the cent, the five
class subtotals add to the whole, and the portfolio still totals
**$482,915.20** against a cost of **$421,711.15** — the total and the
all-time gain of **+$61,204.05 (+14.51 %)** that `Holdings.dc.html` and
`Catalog_HoldingsSummary.dc.html` state. What changed is what the portfolio
holds, not what it is worth.

The portfolio is deliberately fake: no holder name, no wallet address, nothing
that could be mistaken for a real record.
"""

from dataclasses import dataclass
from typing import Final


@dataclass(frozen=True, slots=True)
class LotRow:
    """One curated open lot, positioned relative to ``as_of``."""

    lot_id: str
    symbol: str
    days_before: int
    quantity: str
    cost_basis: str


SEEDED_LOTS: Final[tuple[LotRow, ...]] = (
    # quantity x market price = the market value the list draws; cost_basis /
    # quantity = the average cost printed under the ticker.
    LotRow("lot-btc-01", "BTC", 367, "0.25000000", "9000.00"),
    LotRow("lot-btc-02", "BTC", 363, "1.85000000", "78565.80"),
    # Two lots on purpose, at two costs: FIFO and LIFO must be able to disagree
    # about which one a sale consumes first, and the disagreement must show a
    # different figure, which one lot or one cost cannot (spec 0013 AC-5).
    LotRow("lot-eth-01", "ETH", 800, "18.00000000", "33300.00"),
    LotRow("lot-eth-02", "ETH", 300, "12.00000000", "50100.00"),
    LotRow("lot-sol-01", "SOL", 540, "375.50000000", "66726.35"),
    LotRow("lot-link-01", "LINK", 430, "2100.00000000", "54285.00"),
    LotRow("lot-aave-01", "AAVE", 610, "175.00000000", "31395.00"),
    LotRow("lot-arb-01", "ARB", 480, "50625.00000000", "46575.00"),
    # The settlement asset is a holding, not a special case (OD-1): one unit is
    # one dollar, so quantity is the balance and it can never show a gain.
    LotRow("lot-usdc-01", "USDC", 800, "51764.00000000", "51764.00"),
)

__all__ = ["SEEDED_LOTS", "LotRow"]
