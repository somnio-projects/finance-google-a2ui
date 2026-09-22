"""What a **sell** row says: the trade, what it realised, its term (spec 0028).

Split from `activity_entries.py`: the other kinds are one sentence each; a sale
also walks the ledger for its basis, and that walk deserves its own page.
"""

from collections.abc import Sequence
from typing import Final

from app.domain.activity import Realized, realized_of
from app.domain.day_change import trend_of
from app.domain.transactions import Transaction
from app.presentation.activity_payload import (
    TERM_BADGES,
    ActivityEntry,
    RealizedLine,
    TermBadge,
)
from app.presentation.activity_words import Words
from app.presentation.displays import money

WHOLE_DOLLARS: Final[int] = 0


def sell(words: Words, ledger: Sequence[Transaction]) -> ActivityEntry:
    """``Sold 30 VOO`` with what it realised and its term badge, when known."""
    row = words.row
    realized = realized_of(row, ledger)
    return words.entry(
        title=f"Sold {words.shares} {row.symbol}",
        detail=f"{words.shares} sh @ {words.price} · {words.when}{words.memo}",
        amount=money(row.amount, locale=words.locale),
        tone="flat",
        realized=None if realized is None else _realized_line(realized, words),
        term=None if realized is None else _term_badge(realized),
    )


def _realized_line(realized: Realized, words: Words) -> RealizedLine:
    """``+$588 realized`` in whole dollars, coloured by its sign."""
    amount = words.signed(realized.amount, precision=WHOLE_DOLLARS)
    return RealizedLine(
        amount=amount,
        text=f"{amount.display} realized",
        trend=trend_of(realized.amount),
    )


def _term_badge(realized: Realized) -> TermBadge:
    """``ST gain`` or ``LT gain``, from the term the walk decided."""
    term = realized.term.value
    return TermBadge(term=term, label=TERM_BADGES[term])  # pyright: ignore[reportArgumentType]


__all__ = ["WHOLE_DOLLARS", "sell"]
