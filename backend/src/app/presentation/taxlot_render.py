"""How the tax-lot table's payload is **built** (spec 0015 §4).

Every function here is pure and returns nothing but fragments, strings and
counts, so "did a raw number escape to the widget?" is a question about this
one file. It reads the simulation the domain produced and formats it; it
decides nothing about the sale.

One figure is not plain ``money()``: a **gain or loss** is signed, so a
realised loss cannot be mistaken for a smaller gain (OD-10).

The unit-price builder used to live here too, quoting the price at the
resolution it is actually quoted at (OD-5). It went with the ``price`` total
in spec 0024 §7 — the design draws no unit price, and a figure nothing binds
is a figure nothing checks. It is in the history if the design grows a slot.

``term_split`` is the one to read twice: it iterates ``LotTerm`` rather than
the consumed rows, which is what makes a missing half of the split impossible
rather than merely unlikely.
"""

from decimal import Decimal

from app.core.dates import date_display
from app.core.display import quantity_display
from app.core.period_display import holding_period_display
from app.core.signed_display import signed_money_display
from app.core.trend import trend_of
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.terms import LotTerm
from app.presentation.fragments import MoneyDisplay, SignedTotal
from app.presentation.options import DisplayOptions
from app.presentation.taxlots import TERM_LABELS, TaxLotRow, TermTotal


def signed_money(value: Decimal, options: DisplayOptions) -> MoneyDisplay:
    """Pair a profit or loss with the string that shows its sign."""
    return MoneyDisplay(
        amount=value,
        display=signed_money_display(
            value, precision=options.precision, locale=options.locale
        ),
    )


def units_of(value: Decimal, options: DisplayOptions) -> str:
    """Return a unit count as the trimmed string the table prints."""
    return quantity_display(value, locale=options.locale, trim=True)


def realized_total(result: SaleSimulation, options: DisplayOptions) -> SignedTotal:
    """Pair the realised result with the direction the footer is coloured from.

    ``direction`` comes from ``trend_of``, which decides from the **rounded**
    figure for the same reason the string signs from it: a green total beside a
    ``$0.00`` is a contradiction the reader cannot resolve (spec 0049 OD-4).
    """
    return SignedTotal(
        label="Realised P/L",
        amount=signed_money(result.realized_pl, options),
        direction=trend_of(result.realized_pl, precision=options.precision),
    )


def lot_row(row: LotConsumption, options: DisplayOptions) -> TaxLotRow:
    """Render one consumed lot, carrying the lot's own term through (0013 OD-7).

    The date and the unit count each travel as a pair — the exact value for
    geometry and the string for the screen. Without the second half the client
    had two bad options and took neither: print the raw value, or format it
    itself (spec 0024 §7).
    """
    return TaxLotRow(
        label=row.lot_id,
        acquired_on=row.acquired_on,
        acquired_on_display=date_display(row.acquired_on, locale=options.locale),
        term=row.term,
        holding_period_display=holding_period_display(row.held_days),
        units=row.quantity,
        units_display=units_of(row.quantity, options),
        cost_basis=options.money(row.cost_basis),
        proceeds=options.money(row.proceeds),
        gain_loss=signed_money(row.gain_loss, options),
        trend=trend_of(row.gain_loss, precision=options.precision),
        fully_sold=row.exhausted,
    )


def term_split(
    result: SaleSimulation, options: DisplayOptions
) -> tuple[TermTotal, ...]:
    """Split the realised result by holding period (spec 0015 AC-3).

    Args:
        result: The simulation, straight from the domain.
        options: The validated precision and locale for this render.

    Returns:
        One entry per ``LotTerm``, in enum order — built by iterating the enum
        rather than by looking at the rows, so a term the sale never touched
        still renders at zero instead of disappearing from the comparison.
        The figures come from ``pl_in``/``lots_in``, which re-read the consumed
        rows, so the split cannot disagree with the table beside it.
    """
    return tuple(
        TermTotal(
            label=TERM_LABELS[term],
            term=term,
            lots=result.lots_in(term),
            realized=signed_money(result.pl_in(term), options),
        )
        for term in LotTerm
    )


def subtitle(result: SaleSimulation, options: DisplayOptions, *, method: str) -> str:
    """Return the scenario in words, so the client states no figure itself."""
    return f"Sell {units_of(result.quantity, options)} {result.symbol} under {method}"


__all__ = [
    "lot_row",
    "realized_total",
    "signed_money",
    "subtitle",
    "term_split",
    "units_of",
]
