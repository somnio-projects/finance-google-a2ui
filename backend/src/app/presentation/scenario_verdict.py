"""Who wins each row, which column is recommended, and the sentence (spec 0051).

Every claim here is a **comparison of two figures**, which is exactly what the
client may not perform (N-2). So all of it is decided server-side and shipped
as declared fields: a `winner` per row, a `recommended` flag per column, and
one footer sentence with its figures already in it.

**A tie names nobody.** Proceeds is identical in every column by construction,
and two lot methods can consume the same lots; marking one of them anyway
would be a ranking invented to fill a slot.
"""

from decimal import Decimal
from typing import Final

from app.presentation.displays import MoneyDisplay
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenario_rows import (
    HIGHER,
    ROWS,
    RowKey,
    ScenarioRow,
)

RECOMMENDED: Final[str] = "Recommended"


def _amount(column: ScenarioColumn, key: RowKey) -> Decimal:
    """The exact figure ``key`` names on ``column``."""
    figure: MoneyDisplay = getattr(column, key)
    return figure.amount


def winner_of(
    columns: tuple[ScenarioColumn, ...], key: RowKey, better: str
) -> str | None:
    """The key of the single best column in one row, or null on a tie.

    Args:
        columns: The rendered columns, in arrival order.
        key: The row being decided.
        better: ``HIGHER`` or ``LOWER`` — which way this row wins.

    Returns:
        The winning ``columns[].key``, or ``None`` when two or more columns
        share the best figure.
    """
    amounts = [_amount(column, key) for column in columns]
    best = max(amounts) if better == HIGHER else min(amounts)
    if amounts.count(best) != 1:
        return None
    return columns[amounts.index(best)].key


def rows(columns: tuple[ScenarioColumn, ...]) -> tuple[ScenarioRow, ...]:
    """Lay the comparison out row-major, with each row's winner decided."""
    return tuple(
        ScenarioRow(
            key=key,
            label=label,
            direction_label=better,
            winner=winner_of(columns, key, better),
        )
        for key, label, better in ROWS
    )


def recommended(
    columns: tuple[ScenarioColumn, ...], table: tuple[ScenarioRow, ...]
) -> tuple[ScenarioColumn, ...]:
    """Tag the column that keeps the most after tax, when one does.

    The recommendation **is** the `net_after_tax` row's winner: one claim, one
    source. Deriving it twice is how two fields that nearly agree start to
    disagree.
    """
    net = next(row for row in table if row.key == "net_after_tax")
    return tuple(
        column.model_copy(
            update={
                "recommended": True,
                "recommendation_label": RECOMMENDED,
            }
        )
        if column.key == net.winner
        else column
        for column in columns
    )


__all__ = ["RECOMMENDED", "recommended", "rows", "winner_of"]
