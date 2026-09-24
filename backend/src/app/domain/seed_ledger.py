"""The curated ledger, as data (spec 0035 OD-7, extending 0003 OD-2).

Split from ``seed_data.py`` for the reason ``market_data.py`` is split from
``market.py``: the lots and the ledger are two tables, and 48 rows plus 16
lots do not fit one module under the 150-line budget. ``seed_data`` holds
what is **held**; this holds what **happened**.

Every number is a **string**, parsed to ``Decimal`` by ``Transaction``
(ADR-E D-5), and every row is positioned by ``days_before`` the injected
``as_of`` so the sections come out the same whatever day the demo runs.

**The ledger is hand-reconciled with the lots, and this is the rule
(spec 0035 OD-7).** For every symbol that was sold, the buy carries the lot's
quantity *plus* everything later sold, at the lot's unit cost — so
``buys - sells == the open lot``, to the unit and to the cent, and what the
sale consumed is exactly what the lot no longer holds. Change one quantity
here without changing its partner and
``tests/unit/domain/test_seed_ledger.py`` goes red, which is the point of it.

**TSLA is the deliberate exception**: bought and fully sold, so the timeline
shows a closed position that the holdings list correctly does not carry.

**Income and deposits still do not move the cash lot** (spec 0035 OD-8).
Twenty-five of these rows are dividends and deposits sitting against a
``USD`` balance that is itself seed data. The ledger is the history the
design draws, not a double-entry system; making it one would move every
figure on Home and Holdings for nothing the showcase can use.
"""

# ruff: noqa: E501 -- the ledger is a table a reader compares row against row;
# wrapping each tuple over five lines defeats that, as it does in market_data.
from dataclasses import dataclass
from typing import Final


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
    memo: str | None = None


_QUALIFIED: Final[str] = "qualified"
_PAYROLL: Final[str] = "Payroll · Recurring"

# fmt: off
#: What built the positions. A symbol that was later sold was bought in the
#: larger quantity the sale then reduced (OD-7); NVDA and AAPL keep two lots
#: at two costs, which is what lets FIFO and LIFO disagree (spec 0013 AC-5).
_BUYS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0001", 800, "buy", "AAPL", "200.0000", "155.40", "31080.00"),
    TransactionRow("txn-0016", 300, "buy", "AAPL", "100.0000", "95.40", "9540.00"),
    TransactionRow("txn-0002", 700, "buy", "JNJ", "30.0000", "170.00", "5100.00"),
    TransactionRow("txn-0003", 660, "buy", "PG", "25.0000", "180.00", "4500.00"),
    TransactionRow("txn-0004", 610, "buy", "MSFT", "135.0000", "305.20", "41202.00"),
    TransactionRow("txn-0005", 540, "buy", "VOO", "105.0000", "402.10", "42220.50"),
    TransactionRow("txn-0006", 520, "buy", "AGG", "400.0000", "108.00", "43200.00"),
    TransactionRow("txn-0007", 480, "buy", "XOM", "180.0000", "42.00", "7560.00"),
    TransactionRow("txn-0008", 460, "buy", "TIP", "45.0000", "135.00", "6075.00"),
    TransactionRow("txn-0009", 430, "buy", "BND", "620.0000", "74.10", "45942.00"),
    TransactionRow("txn-0010", 390, "buy", "GLD", "290.0000", "240.00", "69600.00"),
    TransactionRow("txn-0011", 367, "buy", "NVDA", "60.0000", "760.00", "45600.00"),
    TransactionRow("txn-0012", 363, "buy", "NVDA", "30.0000", "960.00", "28800.00"),
    TransactionRow("txn-0013", 350, "buy", "VNQ", "93.0000", "106.51", "9905.43"),
    TransactionRow("txn-0023", 330, "buy", "TSLA", "50.0000", "240.00", "12000.00"),
    # txn-0014 and txn-0015 share a date on purpose: they are what proves the
    # same-date tiebreak in ``Portfolio.transactions`` is stable (0028 AC-4).
    TransactionRow("txn-0014", 210, "buy", "PYPL", "300.0000", "88.60", "26580.00"),
)

#: Seven sales: four gains and three losses, four short-term and three long,
#: so every badge the Activity tab can print is printed by the seed (AC-5).
_SELLS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0024", 300, "sell", "TIP", "15.0000", "128.00", "1920.00"),
    TransactionRow("txn-0015", 210, "sell", "VOO", "20.0000", "489.00", "9780.00"),
    TransactionRow("txn-0025", 168, "sell", "MSFT", "25.0000", "415.00", "10375.00"),
    TransactionRow("txn-0026", 120, "sell", "PYPL", "50.0000", "71.20", "3560.00"),
    TransactionRow("txn-0027", 95, "sell", "XOM", "50.0000", "38.50", "1925.00"),
    TransactionRow("txn-0028", 60, "sell", "TSLA", "50.0000", "291.00", "14550.00"),
    TransactionRow("txn-0029", 20, "sell", "GLD", "40.0000", "262.00", "10480.00"),
)

#: A dividend carries the per-share amount as the price and the shares held
#: **on that day** as the quantity — which is why VOO pays on 105 shares
#: before its sale and on 85 after it.
_DIVIDENDS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0017", 0, "dividend", "VOO", "85.0000", "1.62", "137.70", _QUALIFIED),
    TransactionRow("txn-0019", 9, "dividend", "MSFT", "110.0000", "0.83", "91.30", _QUALIFIED),
    TransactionRow("txn-0030", 35, "dividend", "BND", "620.0000", "0.21", "130.20", _QUALIFIED),
    TransactionRow("txn-0021", 40, "dividend", "AAPL", "300.0000", "0.25", "75.00", _QUALIFIED),
    TransactionRow("txn-0031", 55, "dividend", "PG", "25.0000", "1.01", "25.25", _QUALIFIED),
    TransactionRow("txn-0032", 68, "dividend", "XOM", "130.0000", "0.99", "128.70", _QUALIFIED),
    TransactionRow("txn-0022", 75, "dividend", "JNJ", "30.0000", "1.24", "37.20", _QUALIFIED),
    TransactionRow("txn-0033", 92, "dividend", "VOO", "85.0000", "1.55", "131.75", _QUALIFIED),
    TransactionRow("txn-0034", 99, "dividend", "MSFT", "110.0000", "0.79", "86.90", _QUALIFIED),
    TransactionRow("txn-0035", 127, "dividend", "BND", "620.0000", "0.21", "130.20", _QUALIFIED),
    TransactionRow("txn-0036", 131, "dividend", "AAPL", "300.0000", "0.25", "75.00", _QUALIFIED),
    TransactionRow("txn-0037", 166, "dividend", "JNJ", "30.0000", "1.19", "35.70", _QUALIFIED),
    TransactionRow("txn-0038", 183, "dividend", "VOO", "85.0000", "1.49", "126.65", _QUALIFIED),
    TransactionRow("txn-0039", 190, "dividend", "MSFT", "135.0000", "0.75", "101.25", _QUALIFIED),
    TransactionRow("txn-0040", 222, "dividend", "AAPL", "300.0000", "0.24", "72.00", _QUALIFIED),
    TransactionRow("txn-0041", 275, "dividend", "VOO", "105.0000", "1.44", "151.20", _QUALIFIED),
)

#: Funding. A deposit is ``USD`` at a price of one, so ``amount ==
#: quantity * price`` holds for it like every other kind.
_DEPOSITS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0018", 2, "deposit", "USD", "5000.0000", "1.00", "5000.00", "Bank transfer · Chase ••4021"),
    TransactionRow("txn-0020", 14, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0042", 44, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0043", 74, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0044", 104, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0045", 134, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0046", 165, "deposit", "USD", "3200.0000", "1.00", "3200.00", "Bank transfer · Wells ••7788"),
    TransactionRow("txn-0047", 195, "deposit", "USD", "2500.0000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0048", 240, "deposit", "USD", "7500.0000", "1.00", "7500.00", "Bonus · Annual"),
)
# fmt: on

SEEDED_TRANSACTIONS: Final[tuple[TransactionRow, ...]] = (
    *_BUYS,
    *_SELLS,
    *_DIVIDENDS,
    *_DEPOSITS,
)

__all__ = ["SEEDED_TRANSACTIONS", "TransactionRow"]
