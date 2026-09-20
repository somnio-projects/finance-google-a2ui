"""How the tax-lot table's payload is **built** (spec 0015 §4).

Every function here is pure and returns nothing but fragments, strings and
counts, so "did a raw number escape to the widget?" is a question about this
one file. It reads the simulation the domain produced and formats it; it
decides nothing about the sale.

Two figures are not plain ``money()``. A **gain or loss** is signed, so a
realised loss cannot be mistaken for a smaller gain (OD-10). A **unit price**
keeps the precision it is quoted to rather than the caller's, because the
reader multiplies by it: ``$0.13 x 12,000`` misses the proceeds printed beside
it by $32.40 (OD-5, spec 0013 OD-4).

``term_split`` is the one to read twice: it iterates ``LotTerm`` rather than
the consumed rows, which is what makes a missing half of the split impossible
rather than merely unlikely.
"""

from decimal import Decimal

from app.core.display import price_display, quantity_display, signed_money_display
from app.core.trend import trend_of
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.terms import LotTerm
from app.presentation.fragments import Annotation, MoneyDisplay, Total
from app.presentation.options import DisplayOptions
from app.presentation.tax_lots import TERM_LABELS, TaxLotRow, TermTotal


def signed_money(value: Decimal, options: DisplayOptions) -> MoneyDisplay:
    """Pair a profit or loss with the string that shows its sign."""
    return MoneyDisplay(
        amount=value,
        display=signed_money_display(
            value, precision=options.precision, locale=options.locale
        ),
    )


def price_total(price: Decimal, options: DisplayOptions) -> Total:
    """Render the unit price at the precision it is quoted to, not the caller's."""
    return Total(
        label="Price",
        amount=MoneyDisplay(
            amount=price, display=price_display(price, locale=options.locale)
        ),
    )


def units_of(value: Decimal, options: DisplayOptions) -> str:
    """Return a unit count as the trimmed string the table prints."""
    return quantity_display(value, locale=options.locale, trim=True)


def lot_row(row: LotConsumption, options: DisplayOptions) -> TaxLotRow:
    """Render one consumed lot, carrying the lot's own term through (0013 OD-7)."""
    return TaxLotRow(
        label=row.lot_id,
        acquired_on=row.acquired_on,
        term=row.term,
        units=units_of(row.quantity, options),
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


def remaining_notes(
    result: SaleSimulation, options: DisplayOptions
) -> tuple[Annotation, ...]:
    """Render the position left over — what makes this a decision, not a receipt."""
    return (
        Annotation(
            label="Units left", text=units_of(result.remaining_quantity, options)
        ),
        Annotation(
            label="Cost basis", text=options.money(result.remaining_cost_basis).display
        ),
        Annotation(
            label="Market value",
            text=options.money(result.remaining_market_value()).display,
        ),
        Annotation(label="Open lots", text=str(result.remaining_lots)),
    )


def subtitle(result: SaleSimulation, options: DisplayOptions, *, method: str) -> str:
    """Return the scenario in words, so the client states no figure itself."""
    return f"Sell {units_of(result.quantity, options)} {result.symbol} under {method}"


__all__ = [
    "lot_row",
    "price_total",
    "remaining_notes",
    "signed_money",
    "subtitle",
    "term_split",
    "units_of",
]
