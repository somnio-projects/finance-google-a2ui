"""The columns the redesign adds: after tax, and a column that waits (spec 0051).

``scenario_build`` renders what a lot method changes; this renders what the
**tax rates** change, and the one column that changes neither — it changes
*when*.

**"Wait for long-term" is not a lot method.** It is the same sale, under the
same ordering, at a date past every lot's first anniversary, so the whole
realised result is long-term. That is an assumption worth naming: it holds the
price still, which a year does not. The card says so in its notes rather than
letting the column imply a forecast (spec 0051 OD-2).
"""

from typing import Final

from app.domain.money import ZERO
from app.domain.scenario_tax import TaxRates, estimated_tax, net_after_tax
from app.presentation.options import DisplayOptions
from app.presentation.scenario_build import signed_money
from app.presentation.scenario_columns import ScenarioColumn

#: The timing column's identity, kept out of the method enum.
WAIT_KEY: Final[str] = "wait-long-term"
WAIT_LABEL: Final[str] = "Wait for long-term"
WAIT_CAPTION: Final[str] = "> 12 mo hold"


def taxed(
    column: ScenarioColumn, *, rates: TaxRates, options: DisplayOptions
) -> ScenarioColumn:
    """Return ``column`` with its estimated tax and what it leaves.

    Args:
        column: A column rendered by ``scenario_build.column``.
        rates: The declared rates for this render.
        options: The precision and locale to format under.

    Returns:
        The same column with ``est_tax`` and ``net_after_tax`` filled.
    """
    tax = estimated_tax(
        short_term_pl=column.short_term_pl.amount,
        long_term_pl=column.long_term_pl.amount,
        rates=rates,
    )
    return column.model_copy(
        update={
            "est_tax": options.money(tax),
            "net_after_tax": signed_money(
                net_after_tax(column.realized_pl.amount, tax), options=options
            ),
        }
    )


def waited(
    baseline: ScenarioColumn, *, rates: TaxRates, options: DisplayOptions
) -> ScenarioColumn:
    """Return the *wait for long-term* column, built from ``baseline``.

    Args:
        baseline: The first column — the ordering the reader would use today.
        rates: The declared rates for this render.
        options: The precision and locale to format under.

    Returns:
        The same sale with every lot held past a year: the realised result is
        unchanged and all of it is long-term, so only the tax moves.
    """
    realized = baseline.realized_pl.amount
    tax = estimated_tax(short_term_pl=ZERO, long_term_pl=realized, rates=rates)
    return baseline.model_copy(
        update={
            "key": WAIT_KEY,
            "kind": "timing",
            "label": WAIT_LABEL,
            "caption": WAIT_CAPTION,
            "short_term_pl": signed_money(ZERO, options=options),
            "long_term_pl": signed_money(realized, options=options),
            "short_term_lots": "0",
            "long_term_lots": str(
                int(baseline.short_term_lots) + int(baseline.long_term_lots)
            ),
            "est_tax": options.money(tax),
            "net_after_tax": signed_money(
                net_after_tax(realized, tax), options=options
            ),
        }
    )


__all__ = [
    "WAIT_CAPTION",
    "WAIT_KEY",
    "WAIT_LABEL",
    "taxed",
    "waited",
]
