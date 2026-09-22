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


def _dividend(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Dividend — VOO`` · ``$1.62/sh · 85 sh · qualified`` · green ``+``."""
    del ledger
    row = words.row
    return words.entry(
        title=f"Dividend — {row.symbol}",
        detail=f"{words.price}/sh · {words.shares} sh{words.memo}",
        amount=words.signed(row.amount),
        tone="up",
    )


def _deposit(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Deposit — Bank transfer`` · ``Chase ••4021 · Mon`` · green ``+``."""
    del ledger
    row = words.row
    source, *rest = (row.memo or "").split(MEMO_SEPARATOR)
    title = f"Deposit — {source}" if source else "Deposit"
    detail = MEMO_SEPARATOR.join([*rest, words.when])
    return words.entry(
        title=title, detail=detail, amount=words.signed(row.amount), tone="up"
    )


def _buy(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Bought 60 NVDA`` · ``60 sh @ $760.00 · Sep 16`` · a neutral ``-``."""
    del ledger
    row = words.row
    return words.entry(
        title=f"Bought {words.shares} {row.symbol}",
        detail=f"{words.shares} sh @ {words.price} · {words.when}{words.memo}",
        amount=words.signed(-row.amount),
        tone="flat",
    )


_Writer = Callable[[Words, Sequence[Transaction]], ActivityEntry]
_WRITERS: Final[dict[TransactionType, _Writer]] = {
    TransactionType.DIVIDEND: _dividend,
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
