"""The pieces every Activity row is spelled from, computed once (spec 0028).

Split from `activity_entries.py` under the 150-line budget: this module knows
how a day and a figure print; that one knows what each kind of row says.
"""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Final

from app.core.calendar_words import month_day_label, weekday_label
from app.core.signed_display import signed_money_display
from app.domain.day_change import Trend
from app.domain.transactions import Transaction
from app.presentation.activity_payload import (
    BADGES,
    ActivityEntry,
    RealizedLine,
    TermBadge,
)
from app.presentation.displays import MoneyDisplay

TODAY_WORD: Final[str] = "Today"
WEEK_DAYS: Final[int] = 7
WHOLE_DOLLARS: Final[int] = 0
MEMO_SEPARATOR: Final[str] = " · "


def when_label(day: date, *, as_of: date, locale: str) -> str:
    """The day a row prints: ``Wed`` inside the week, ``Sep 12`` beyond."""
    age = (as_of - day).days
    if age == 0:
        return TODAY_WORD
    if age < WEEK_DAYS:
        return weekday_label(day, locale=locale)
    return month_day_label(day, locale=locale)


@dataclass(frozen=True)
class Words:
    """The pieces every writer spells from: computed once per row."""

    row: Transaction
    locale: str
    when: str
    shares: str
    price: str

    @property
    def memo(self) -> str:
        """The row's memo as a trailing caption piece, or nothing."""
        return f"{MEMO_SEPARATOR}{self.row.memo}" if self.row.memo else ""

    def signed(self, amount: Decimal, *, precision: int = 2) -> MoneyDisplay:
        """An ADR-E pair with an explicit sign, in this row's locale."""
        display = signed_money_display(amount, precision=precision, locale=self.locale)
        return MoneyDisplay(amount=amount, display=display)

    def entry(
        self,
        *,
        title: str,
        detail: str,
        amount: MoneyDisplay,
        tone: Trend,
        realized: RealizedLine | None = None,
        term: TermBadge | None = None,
    ) -> ActivityEntry:
        """Assemble the DTO around this row; the badge is the kind's word."""
        return ActivityEntry(
            key=self.row.transaction_id,
            kind=self.row.kind.value,
            title=title,
            detail=detail,  # pyright: ignore[reportArgumentType]
            amount=amount,
            tone=tone,
            badge=BADGES[self.row.kind.value],
            realized=realized,
            term=term,
        )


__all__ = ["MEMO_SEPARATOR", "TODAY_WORD", "WEEK_DAYS", "Words", "when_label"]
