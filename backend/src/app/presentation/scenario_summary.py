"""The comparison's footer sentence (spec 0051 OD-5).

Split from ``scenario_verdict`` at the file budget, along a real seam: that
module **decides** which column wins, this one **says so in a sentence**. A
spread is a fact about the data and names neither end better; a footer is a
claim about it, and the two are kept apart on purpose.

Composed here so no client assembles prose around two figures (N-9).
"""

from decimal import Decimal
from typing import Final

from app.presentation.displays import MoneyDisplay
from app.presentation.options import DisplayOptions
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenario_rows import ScenarioRow, ScenarioSummary

#: The pill in the header.
BEST_RESULT: Final[str] = "Best result"
#: One column keeps more than the ordering a reader would have used anyway.
SAVES: Final[str] = "{label} saves {tax} in tax and keeps {net} more after tax."
#: The winner **is** that ordering. Saying it "saves" something would be
#: comparing it with itself.
ALREADY: Final[str] = "{label} already keeps the most after tax here."
#: Every column lands in the same place.
LEVEL: Final[str] = "Every scenario leaves the same after tax, so none is better."
#: Some columns tie at the top and others do not. Saying "every scenario
#: leaves the same" here would be false, and it was: with the timing column
#: added, waiting changed nothing for a baseline already wholly long-term, so
#: two columns tied for best while two others trailed — and the footer claimed
#: they were all level. Found by a manual run (spec 0051 §7).
TIED: Final[str] = "{count} scenarios keep the most after tax, so none is marked."


def _net(column: ScenarioColumn) -> Decimal:
    """What this column leaves after tax, exactly."""
    figure: MoneyDisplay = column.net_after_tax
    return figure.amount


def _no_winner(columns: tuple[ScenarioColumn, ...]) -> str:
    """The sentence for a row nobody won: all level, or only some tied."""
    amounts = [_net(column) for column in columns]
    if len(set(amounts)) == 1:
        return LEVEL
    return TIED.format(count=amounts.count(max(amounts)))


def summarise(
    columns: tuple[ScenarioColumn, ...],
    table: tuple[ScenarioRow, ...],
    *,
    options: DisplayOptions,
) -> ScenarioSummary:
    """Write the footer against the first column — the ordering used today.

    Args:
        columns: The rendered columns; ``columns[0]`` is the baseline.
        table: The rows, already decided.
        options: The precision and locale to format under.

    Returns:
        The sentence, with both figures in it, or a flat one when nothing wins.
    """
    net = next(row for row in table if row.key == "net_after_tax")
    best = next((column for column in columns if column.key == net.winner), None)
    if best is None:
        return ScenarioSummary(text=_no_winner(columns), badge=BEST_RESULT)
    base = columns[0]
    if best.key == base.key:
        # Not a tie — the baseline won. `LEVEL` here would have been false,
        # and was: the first render said "every scenario leaves the same"
        # beside a column marked Recommended.
        return ScenarioSummary(text=ALREADY.format(label=best.label), badge=BEST_RESULT)
    saved = base.est_tax.amount - best.est_tax.amount
    kept = best.net_after_tax.amount - base.net_after_tax.amount
    return ScenarioSummary(
        text=SAVES.format(
            label=best.label,
            tax=options.money(saved).display,
            net=options.money(kept).display,
        ),
        badge=BEST_RESULT,
    )


__all__ = ["ALREADY", "BEST_RESULT", "LEVEL", "SAVES", "TIED", "summarise"]
