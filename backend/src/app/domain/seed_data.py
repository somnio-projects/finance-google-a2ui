"""The curated demo portfolio, as data (spec 0003 OD-2).

Code-defined rather than a JSON fixture: a file that never changes at runtime
does not deserve its own loader, its own validation path and its own failure
modes. Every number is a **string**, parsed to ``Decimal`` by the entities in
``app.domain.seed`` (ADR-E D-5).

Lots are positioned by ``days_before`` the injected ``as_of`` instead of by
absolute date, so the demo cases hold whatever day the demo runs:

* **NVDA** carries the tax-lot story: lots straddling the 1-year boundary, one
  at 367 days (long) and one at 363 days (short, two days inside it).
* **PYPL**, **BND** and **XOM** carry the attribution story: losers standing
  next to NVDA's and AAPL's gains.
* **VOO** carries the order/payoff story: units bought and partly sold, so a
  simulated sale has a real history behind it.

**The figures are the design's, and they reconcile (spec 0025 §2).** Quantity
times price equals the market value `Holdings.dc.html` draws, to the cent; the
four class subtotals equal the ones `Catalog_HoldingsSummary.dc.html` states;
and the whole thing sums to **$482,915.20**. Seven positions are the ones the
design draws, in its order. The rest are below the fold of a scrollable list
and are invented here, constrained by the class totals — see OD-1, which says
so rather than hiding it.

The portfolio is deliberately fake: no holder name, no account number, nothing
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


@dataclass(frozen=True, slots=True)
class TransactionRow:
    """One curated ledger row, positioned relative to ``as_of``."""

    transaction_id: str
    days_before: int
    kind: str
    symbol: str
    quantity: str
    price: str
    amount: str


SEEDED_LOTS: Final[tuple[LotRow, ...]] = (
    # The design's seven, in its order. quantity x market price = the market
    # value it draws; quantity x cost_basis-per-unit = the average cost it
    # prints under the ticker.
    LotRow("lot-nvda-01", "NVDA", 367, "60.0000", "45600.00"),
    LotRow("lot-nvda-02", "NVDA", 363, "30.0000", "28800.00"),
    # Two lots on purpose, at two costs: FIFO and LIFO must be able to disagree
    # about which one a sale consumes first, and the disagreement must show a
    # different figure, which one lot or one cost cannot (spec 0013 AC-5). The
    # $6,000 the second NVDA lot costs more is what the second AAPL lot costs
    # less, so the all-time gain the design states holds.
    LotRow("lot-aapl-01", "AAPL", 800, "200.0000", "31080.00"),
    LotRow("lot-aapl-02", "AAPL", 300, "100.0000", "9540.00"),
    LotRow("lot-msft-01", "MSFT", 610, "110.0000", "33572.00"),
    LotRow("lot-voo-01", "VOO", 540, "85.0000", "34178.50"),
    LotRow("lot-bnd-01", "BND", 430, "620.0000", "45942.00"),
    LotRow("lot-pypl-01", "PYPL", 210, "250.0000", "22150.00"),
    # Below the fold (OD-1). Their cost bases are what make the all-time gain
    # the design states: +$61,203.89, printed as +$61,204 (+14.5%).
    LotRow("lot-jnj-01", "JNJ", 700, "30.0000", "5100.00"),
    LotRow("lot-pg-01", "PG", 660, "25.0000", "4500.00"),
    LotRow("lot-xom-01", "XOM", 480, "130.0000", "5460.00"),
    LotRow("lot-agg-01", "AGG", 520, "400.0000", "43200.00"),
    LotRow("lot-tip-01", "TIP", 460, "30.0000", "4050.00"),
    LotRow("lot-gld-01", "GLD", 390, "250.0000", "60000.00"),
    LotRow("lot-vnq-01", "VNQ", 350, "93.0000", "9905.43"),
    # Cash is a holding, not a special case (OD-6): one unit is one dollar, so
    # quantity is the balance and it can never show a gain.
    LotRow("lot-usd-01", "USD", 800, "38633.2200", "38633.22"),
)

SEEDED_TRANSACTIONS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0001", 800, "buy", "AAPL", "200.0000", "155.40", "31080.00"),
    TransactionRow("txn-0016", 300, "buy", "AAPL", "100.0000", "95.40", "9540.00"),
    TransactionRow("txn-0002", 700, "buy", "JNJ", "30.0000", "170.00", "5100.00"),
    TransactionRow("txn-0003", 660, "buy", "PG", "25.0000", "180.00", "4500.00"),
    TransactionRow("txn-0004", 610, "buy", "MSFT", "110.0000", "305.20", "33572.00"),
    TransactionRow("txn-0005", 540, "buy", "VOO", "105.0000", "402.10", "42220.50"),
    TransactionRow("txn-0006", 520, "buy", "AGG", "400.0000", "108.00", "43200.00"),
    TransactionRow("txn-0007", 480, "buy", "XOM", "130.0000", "42.00", "5460.00"),
    TransactionRow("txn-0008", 460, "buy", "TIP", "30.0000", "135.00", "4050.00"),
    TransactionRow("txn-0009", 430, "buy", "BND", "620.0000", "74.10", "45942.00"),
    TransactionRow("txn-0010", 390, "buy", "GLD", "250.0000", "240.00", "60000.00"),
    TransactionRow("txn-0011", 367, "buy", "NVDA", "60.0000", "760.00", "45600.00"),
    TransactionRow("txn-0012", 363, "buy", "NVDA", "30.0000", "960.00", "28800.00"),
    TransactionRow("txn-0013", 350, "buy", "VNQ", "93.0000", "106.51", "9905.43"),
    # txn-0014 and txn-0015 share a date on purpose: they are what proves the
    # same-date tiebreak in ``Portfolio.transactions`` is stable (AC-4).
    TransactionRow("txn-0014", 210, "buy", "PYPL", "250.0000", "88.60", "22150.00"),
    TransactionRow("txn-0015", 210, "sell", "VOO", "20.0000", "489.00", "9780.00"),
)

__all__ = ["SEEDED_LOTS", "SEEDED_TRANSACTIONS", "LotRow", "TransactionRow"]
