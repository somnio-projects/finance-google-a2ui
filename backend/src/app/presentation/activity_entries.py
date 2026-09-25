"""Write one ledger row down the way `Activity.dc.html` draws its kind (spec 0028).

One writer per kind, picked from a table: a new kind is one function and one
table entry, not another branch in a chain.
"""

from collections.abc import Callable, Sequence
from datetime import date
from typing import Final

from app.core.display import quantity_display
from app.domain.transactions import Transaction, TransactionType
from app.presentation.activity_payload import ActivityEntry
from app.presentation.activity_sell import sell
from app.presentation.activity_words import (
    MEMO_SEPARATOR,
    TODAY_WORD,
    WEEK_DAYS,
    Words,
    when_label,
)
from app.presentation.displays import money
from app.presentation.options import DisplayOptions


def _reward(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Staking — ETH`` · ``$3,480.00/unit · 0.075 units · …`` · green ``+``.

    A reward is paid **in the asset** (spec 0044 OD-7), so the price is the
    unit price on the day and the quantity is what arrived — the same pair a
    dividend carried, counting units instead of shares.
    """
    del ledger
    row = words.row
    return words.entry(
        title=f"Staking — {row.symbol}",
        detail=f"{words.price}/unit · {words.shares} units{words.memo}",
        amount=words.signed(row.amount),
        tone="up",
    )


def _deposit(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Deposit — Transfer in`` · ``Coinbase ••4021 · Mon`` · green ``+``."""
    del ledger
    row = words.row
    source, *rest = (row.memo or "").split(MEMO_SEPARATOR)
    title = f"Deposit — {source}" if source else "Deposit"
    detail = MEMO_SEPARATOR.join([*rest, words.when])
    return words.entry(
        title=title, detail=detail, amount=words.signed(row.amount), tone="up"
    )


def _buy(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Bought 1.6 BTC`` · ``1.6 units @ $36,000.00 · Sep 16`` · neutral ``-``."""
    del ledger
    row = words.row
    return words.entry(
        title=f"Bought {words.shares} {row.symbol}",
        detail=f"{words.shares} units @ {words.price} · {words.when}{words.memo}",
        amount=words.signed(-row.amount),
        tone="flat",
    )


_Writer = Callable[[Words, Sequence[Transaction]], ActivityEntry]
_WRITERS: Final[dict[TransactionType, _Writer]] = {
    TransactionType.STAKING_REWARD: _reward,
    TransactionType.DEPOSIT: _deposit,
    TransactionType.BUY: _buy,
    TransactionType.SELL: sell,
}


def entry_of(
    row: Transaction,
    ledger: Sequence[Transaction],
    *,
    as_of: date,
    options: DisplayOptions,
) -> ActivityEntry:
    """Write one ledger row down as the design draws its kind."""
    locale = options.locale
    words = Words(
        row=row,
        locale=locale,
        when=when_label(row.occurred_on, as_of=as_of, locale=locale),
        shares=quantity_display(row.quantity, locale=locale, trim=True),
        price=money(row.price, locale=locale).display,
    )
    return _WRITERS[row.kind](words, ledger)


__all__ = ["TODAY_WORD", "WEEK_DAYS", "entry_of", "when_label"]
