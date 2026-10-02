"""Section the ledger into the Activity tab's dated groups (spec 0028).

``activity_entries`` writes one row down; this module decides which rows the
options keep and under which heading each one goes.
"""

from collections.abc import Sequence
from datetime import date
from typing import Final

from pydantic import Field

from app.core.calendar_words import month_year_heading
from app.domain.transactions import Transaction
from app.presentation.activity_entries import entry_of
from app.presentation.activity_payload import ActivityEntry, ActivityGroup, Kind
from app.presentation.options import DisplayOptions
from app.presentation.search import SearchOptions, matches

TODAY: Final[str] = "TODAY"
THIS_WEEK: Final[str] = "THIS WEEK"
WEEK_DAYS: Final[int] = 7
WHOLE_DOLLARS: Final[int] = 0


class ActivityOptions(DisplayOptions, SearchOptions):
    """The display knobs, which kinds to show, what to search, how many."""

    kind: Kind = Field(
        default="all", description="Which rows to show.", examples=["staking_reward"]
    )
    limit: int = Field(default=100, ge=1, le=200, description="Newest rows kept.")


def kept(row: Transaction, *, options: ActivityOptions, needle: str) -> bool:
    """Whether the chip and the search between them keep ``row``.

    The two compose with **and**: `Sells` plus `btc` is the BTC sale, not
    every sell and every BTC row. The needle is matched against the domain's
    own fields — the symbol and the memo — never against the caption this
    module is about to write (spec 0035 OD-6).
    """
    of_kind = options.kind == "all" or row.kind.value == options.kind
    return of_kind and matches(needle, row.symbol, row.memo)


def section_label(day: date, *, as_of: date, locale: str) -> str:
    """``TODAY`` · ``THIS WEEK`` · ``SEPTEMBER 2026``."""
    age = (as_of - day).days
    if age == 0:
        return TODAY
    if age < WEEK_DAYS:
        return THIS_WEEK
    return month_year_heading(day, locale=locale)


def groups_for(
    ledger: Sequence[Transaction], *, as_of: date, options: ActivityOptions
) -> tuple[ActivityGroup, ...]:
    """Section the newest ``limit`` rows the options keep, newest first."""
    needle = options.needle
    rows = [row for row in ledger if kept(row, options=options, needle=needle)]
    rows = rows[: options.limit]
    sections: dict[str, list[ActivityEntry]] = {}
    for row in rows:
        label = section_label(row.occurred_on, as_of=as_of, locale=options.locale)
        sections.setdefault(label, []).append(
            entry_of(row, ledger, as_of=as_of, options=options)
        )
    return tuple(
        ActivityGroup(label=label, entries=tuple(entries))
        for label, entries in sections.items()
    )


__all__ = [
    "THIS_WEEK",
    "TODAY",
    "WEEK_DAYS",
    "ActivityOptions",
    "groups_for",
    "kept",
    "section_label",
]
