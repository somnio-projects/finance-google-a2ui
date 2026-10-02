"""The distance between the extremes of a comparison (spec 0017 OD-4).

Split from ``scenario_build`` at the file budget when the columns grew their
after-tax rows. The seam is the one already there: what a **column** shows,
apart from what the **set** of them shows.

It reports a gap and names its two ends; it calls neither better. That is
``scenario_verdict``'s job now, and the two are deliberately separate — a
spread is a fact about the data, a recommendation is a claim about it.
"""

from app.domain.money import ZERO
from app.presentation.options import DisplayOptions
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenarios import ScenarioSpread


def spread(
    columns: tuple[ScenarioColumn, ...], *, options: DisplayOptions
) -> ScenarioSpread:
    """Report the distance between the extremes, naming neither as better.

    Args:
        columns: The rendered columns, in the caller's requested order.
        options: The precision and locale to format under.

    Returns:
        The gap and the two methods at its ends, or a flat spread naming
        nobody when every method realises the same (spec 0017 OD-4).
    """
    best = max(columns, key=lambda row: row.realized_pl.amount)
    worst = min(columns, key=lambda row: row.realized_pl.amount)
    gap = best.realized_pl.amount - worst.realized_pl.amount
    if gap == ZERO:
        return ScenarioSpread(amount=options.money(ZERO), differs=False)
    return ScenarioSpread(
        amount=options.money(gap),
        differs=True,
        highest=best.method,
        lowest=worst.method,
    )


__all__ = ["spread"]
