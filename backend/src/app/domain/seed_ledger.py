"""The curated ledger, as data (spec 0044, 0035 OD-7, extending 0003 OD-2).

Split from ``seed_data.py`` for the reason ``market_data.py`` is split from
``market.py``: the lots and the ledger are two tables. ``seed_data`` holds
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

**AVAX is the deliberate exception**: bought and fully sold, so the timeline
shows a closed position that the holdings list correctly does not carry.

**Seven sales, and the badges are the reason there are seven**: four gains and
three losses, four short-term and three long, so every badge the Activity tab
can print is printed by the seed (spec 0028 AC-5). One sale per symbol, so
each walks its own buys.

**Staking rewards replace dividends (spec 0044 OD-7).** A token has no
dividend; the demo's yield-bearing assets pay *in the asset*, so a reward
carries the units received as its quantity and that day's unit price as its
price, and ``amount == quantity * price`` holds for it as for every other
kind. BTC pays none — proof of work has nothing to stake — and neither does
USDC, because a yield this showcase does not model is not one it should claim.

**Rewards and deposits still do not move the settlement lot** (spec 0035
OD-8). Twenty-five of these rows are rewards and deposits sitting against a
``USDC`` balance that is itself seed data. The ledger is the history the
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


_PROTOCOL: Final[str] = "protocol reward"
_PAYROLL: Final[str] = "Payroll · Recurring"

# fmt: off
#: What built the positions. A symbol that was later sold was bought in the
#: larger quantity the sale then reduced (OD-7); BTC and ETH keep two lots at
#: two costs, which is what lets FIFO and LIFO disagree (spec 0013 AC-5).
#: txn-0009 and txn-0010 share a date on purpose: they are what proves the
#: same-date tiebreak in ``Portfolio.transactions`` is stable (0028 AC-4).
_BUYS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0001", 800, "buy", "ETH", "20.50000000", "1850.00", "37925.00"),
    TransactionRow("txn-0002", 610, "buy", "AAVE", "200.00000000", "179.40", "35880.00"),
    TransactionRow("txn-0003", 540, "buy", "SOL", "435.50000000", "177.70", "77388.35"),
    TransactionRow("txn-0004", 480, "buy", "ARB", "58625.00000000", "0.9200", "53935.00"),
    TransactionRow("txn-0005", 430, "buy", "LINK", "2500.00000000", "25.85", "64625.00"),
    TransactionRow("txn-0006", 367, "buy", "BTC", "0.50000000", "36000.00", "18000.00"),
    TransactionRow("txn-0007", 363, "buy", "BTC", "1.85000000", "42468.00", "78565.80"),
    TransactionRow("txn-0008", 330, "buy", "AVAX", "900.00000000", "30.00", "27000.00"),
    TransactionRow("txn-0009", 300, "buy", "ETH", "12.00000000", "4175.00", "50100.00"),
)

#: Four gains and three losses, four short-term and three long.
_SELLS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0010", 300, "sell", "ARB", "8000.00000000", "1.2400", "9920.00"),
    TransactionRow("txn-0011", 210, "sell", "ETH", "2.50000000", "3150.00", "7875.00"),
    TransactionRow("txn-0012", 168, "sell", "AAVE", "25.00000000", "150.00", "3750.00"),
    TransactionRow("txn-0013", 120, "sell", "SOL", "60.00000000", "145.00", "8700.00"),
    TransactionRow("txn-0014", 95, "sell", "LINK", "400.00000000", "19.80", "7920.00"),
    TransactionRow("txn-0015", 60, "sell", "BTC", "0.25000000", "58400.00", "14600.00"),
    TransactionRow("txn-0016", 20, "sell", "AVAX", "900.00000000", "52.00", "46800.00"),
)

#: A reward is paid in the asset: units received as the quantity, that day's
#: unit price as the price. AVAX earns only while it was held, which is why
#: its two rows sit between its buy at 330 days and its sale at 20.
_REWARDS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0017", 0, "staking_reward", "ETH", "0.07500000", "3480.00", "261.00", _PROTOCOL),
    TransactionRow("txn-0018", 7, "staking_reward", "SOL", "2.20000000", "152.40", "335.28", _PROTOCOL),
    TransactionRow("txn-0019", 14, "staking_reward", "LINK", "12.00000000", "22.60", "271.20", _PROTOCOL),
    TransactionRow("txn-0020", 21, "staking_reward", "AAVE", "0.50000000", "248.00", "124.00", _PROTOCOL),
    TransactionRow("txn-0021", 35, "staking_reward", "ETH", "0.07500000", "3400.00", "255.00", _PROTOCOL),
    TransactionRow("txn-0022", 49, "staking_reward", "SOL", "2.20000000", "148.00", "325.60", _PROTOCOL),
    TransactionRow("txn-0023", 63, "staking_reward", "LINK", "12.00000000", "21.50", "258.00", _PROTOCOL),
    TransactionRow("txn-0024", 77, "staking_reward", "AAVE", "0.50000000", "232.00", "116.00", _PROTOCOL),
    TransactionRow("txn-0025", 92, "staking_reward", "ETH", "0.07500000", "3280.00", "246.00", _PROTOCOL),
    TransactionRow("txn-0026", 106, "staking_reward", "SOL", "2.20000000", "160.00", "352.00", _PROTOCOL),
    TransactionRow("txn-0027", 120, "staking_reward", "LINK", "12.00000000", "24.00", "288.00", _PROTOCOL),
    TransactionRow("txn-0028", 140, "staking_reward", "AVAX", "6.00000000", "45.00", "270.00", _PROTOCOL),
    TransactionRow("txn-0029", 155, "staking_reward", "ETH", "0.07500000", "3120.00", "234.00", _PROTOCOL),
    TransactionRow("txn-0030", 175, "staking_reward", "SOL", "2.20000000", "138.00", "303.60", _PROTOCOL),
    TransactionRow("txn-0031", 190, "staking_reward", "AVAX", "6.00000000", "38.50", "231.00", _PROTOCOL),
    TransactionRow("txn-0032", 210, "staking_reward", "LINK", "12.00000000", "26.00", "312.00", _PROTOCOL),
)

#: Funding. A deposit is ``USDC`` at a price of one, so ``amount ==
#: quantity * price`` holds for it like every other kind.
_DEPOSITS: Final[tuple[TransactionRow, ...]] = (
    TransactionRow("txn-0033", 2, "deposit", "USDC", "5000.00000000", "1.00", "5000.00", "Transfer in · Coinbase ••4021"),
    TransactionRow("txn-0034", 14, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0035", 44, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0036", 74, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0037", 104, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0038", 134, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0039", 165, "deposit", "USDC", "3200.00000000", "1.00", "3200.00", "Transfer in · Kraken ••7788"),
    TransactionRow("txn-0040", 195, "deposit", "USDC", "2500.00000000", "1.00", "2500.00", _PAYROLL),
    TransactionRow("txn-0041", 240, "deposit", "USDC", "7500.00000000", "1.00", "7500.00", "Bonus · Annual"),
)
# fmt: on

SEEDED_TRANSACTIONS: Final[tuple[TransactionRow, ...]] = (
    *_BUYS,
    *_SELLS,
    *_REWARDS,
    *_DEPOSITS,
)

__all__ = ["SEEDED_TRANSACTIONS", "TransactionRow"]
