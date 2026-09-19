"""The curated demo portfolio, as data (spec 0003 OD-2).

Code-defined rather than a JSON fixture: a file that never changes at runtime
does not deserve its own loader, its own validation path and its own failure
modes. Every number is a **string**, parsed to ``Decimal`` by the entities in
``app.domain.seed`` (ADR-E D-5).

Lots are positioned by ``days_before`` the injected ``as_of`` instead of by
absolute date, so the three demo cases hold whatever day the demo runs:

* **BTC** carries the tax-lot story: two lots straddling the 1-year boundary,
  one at 367 days (long) and one at 363 days (short, two days inside it).
* **ETH** and **LINK** carry the attribution story: losers standing next to
  BTC's and SOL's gains.
* **SOL** carries the order/payoff story: 60 units bought, 20 sold, 40 open,
  so a simulated sale has a real history behind it.

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
    LotRow("lot-btc-01", "BTC", 367, "0.4200", "18060.00"),
    LotRow("lot-btc-02", "BTC", 363, "0.1800", "10260.00"),
    LotRow("lot-eth-01", "ETH", 800, "3.0000", "11400.00"),
    LotRow("lot-eth-02", "ETH", 120, "2.0000", "7300.00"),
    LotRow("lot-sol-01", "SOL", 210, "40.0000", "4600.00"),
    LotRow("lot-link-01", "LINK", 430, "250.0000", "3625.00"),
    LotRow("lot-doge-01", "DOGE", 95, "12000.00000000", "1680.00"),
)

SEEDED_TRANSACTIONS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0001", 800, "buy", "ETH", "3.0000", "3800.00", "11400.00"),
    TransactionRow("txn-0002", 430, "buy", "LINK", "250.0000", "14.50", "3625.00"),
    TransactionRow("txn-0003", 367, "buy", "BTC", "0.4200", "43000.00", "18060.00"),
    TransactionRow("txn-0004", 363, "buy", "BTC", "0.1800", "57000.00", "10260.00"),
    TransactionRow("txn-0005", 210, "buy", "SOL", "60.0000", "115.00", "6900.00"),
    # txn-0006 and txn-0007 share a date on purpose: they are what proves the
    # same-date tiebreak in ``Portfolio.transactions`` is stable (AC-4).
    TransactionRow("txn-0006", 120, "buy", "ETH", "2.0000", "3650.00", "7300.00"),
    TransactionRow("txn-0007", 120, "sell", "SOL", "20.0000", "138.00", "2760.00"),
    TransactionRow("txn-0008", 95, "buy", "DOGE", "12000.00000000", "0.14", "1680.00"),
)

__all__ = ["SEEDED_LOTS", "SEEDED_TRANSACTIONS", "LotRow", "TransactionRow"]
