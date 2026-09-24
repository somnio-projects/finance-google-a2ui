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
    ActivityEntry,
    RealizedLine,
    TermBadge,
)
from app.presentation.activity_words import Words
from app.presentation.displays import money

WHOLE_DOLLARS: Final[int] = 0
#: `Activity.dc.html` colours the badge by term — amber ST, teal LT — and
#: the colour still comes from `term`. The *word* comes from the sign, which
#: it did not until spec 0035 OD-5: `TERM_BADGES` said "gain" unconditionally,
#: invisible while the seed held one sale and that sale was a gain.
TERM_WORDS: Final[dict[str, str]] = {"short": "ST", "long": "LT"}
RESULT_WORDS: Final[dict[str, str]] = {"up": "gain", "down": "loss", "flat": "even"}


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
    """``ST gain`` · ``ST loss`` · ``LT gain`` · ``LT loss`` (spec 0035 OD-5)."""
    term = realized.term.value
    word = RESULT_WORDS[trend_of(realized.amount)]
    return TermBadge(term=term, label=f"{TERM_WORDS[term]} {word}")  # pyright: ignore[reportArgumentType]


__all__ = ["RESULT_WORDS", "TERM_WORDS", "WHOLE_DOLLARS", "sell"]
