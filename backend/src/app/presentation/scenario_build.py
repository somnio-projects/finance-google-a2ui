"""Filling the scenario shapes from simulated sales (spec 0017 §3).

Pure functions, *(domain result, options) → fragment*: they read no clock, no
repository and no settings, and they decide nothing about the sale — the walk
that costs it lives in ``app.domain.sales`` and stays there.

``signed_money`` and ``price_pair`` are candidates for the shared fragment set
in ``displays.py``; they stay here until a PR can promote them and update every
caller at once, rather than a feature PR editing a shared file (spec 0017
OD-7, ADR-K D-15/D-16).
"""

from decimal import Decimal

from app.core.display import price_display, quantity_display
from app.core.signed_display import signed_money_display
from app.domain.lot_selection import LotMethod
from app.domain.money import ZERO
from app.domain.sale_results import SaleSimulation
from app.domain.terms import LotTerm
from app.presentation.displays import MoneyDisplay
from app.presentation.options import DisplayOptions
from app.presentation.scenario_captions import CAPTIONS
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenarios import (
    METHOD_LABELS,
    ScenarioSubject,
)


def signed_money(value: Decimal, *, options: DisplayOptions) -> MoneyDisplay:
    """Pair an exact amount with a string whose sign is explicit.

    Args:
        value: The exact profit or loss.
        options: The precision and locale to format under.

    Returns:
        ``+$3,825.00`` for a gain, ``-$1,305.00`` for a loss, unsigned when it
        rounds flat — ``+$0.00`` would claim a gain that is not there.
    """
    return MoneyDisplay(
        amount=value,
        display=signed_money_display(
            value, precision=options.precision, locale=options.locale
        ),
    )


def price_pair(value: Decimal, *, options: DisplayOptions) -> MoneyDisplay:
    """Pair a unit price with a string quoted as far as the price goes.

    Args:
        value: The exact reference price.
        options: The locale to format under; a price sets its own precision.

    Returns:
        The pair, so a sub-cent asset ties out against the quantity beside it
        (spec 0013 OD-4).
    """
    return MoneyDisplay(
        amount=value, display=price_display(value, locale=options.locale)
    )


def column(
    simulation: SaleSimulation, *, method: LotMethod, options: DisplayOptions
) -> ScenarioColumn:
    """Render one simulation as the column the reader compares.

    Args:
        simulation: What this method's sale realised.
        method: The method that produced it.
        options: The precision and locale to format under.

    Returns:
        The column, every figure already formatted. ``est_tax`` and
        ``net_after_tax`` land at zero here and are filled by
        ``scenario_after_tax.taxed``: they depend on the declared rates, which
        are not this function's business (spec 0051).
    """
    return ScenarioColumn(
        key=method.value.lower(),
        method=method,
        label=METHOD_LABELS[method],
        caption=CAPTIONS[method],
        proceeds=options.money(simulation.proceeds),
        cost_basis=options.money(simulation.cost_basis),
        realized_pl=signed_money(simulation.realized_pl, options=options),
        short_term_pl=signed_money(simulation.pl_in(LotTerm.SHORT), options=options),
        long_term_pl=signed_money(simulation.pl_in(LotTerm.LONG), options=options),
        est_tax=options.money(ZERO),
        net_after_tax=signed_money(ZERO, options=options),
        short_term_lots=str(simulation.lots_in(LotTerm.SHORT)),
        long_term_lots=str(simulation.lots_in(LotTerm.LONG)),
        lots=tuple(row.lot_id for row in simulation.consumed),
    )


def subject(
    simulation: SaleSimulation, *, name: str, options: DisplayOptions
) -> ScenarioSubject:
    """Render what the columns hold fixed: symbol, units, price, proceeds.

    Args:
        simulation: Any of them — these four agree across every method.
        name: The asset's display name.
        options: The precision and locale to format under.

    Returns:
        The shared header of the card.
    """
    return ScenarioSubject(
        label=name,
        symbol=simulation.symbol,
        quantity_display=quantity_display(
            simulation.quantity, locale=options.locale, trim=True
        ),
        price=price_pair(simulation.price, options=options),
        proceeds=options.money(simulation.proceeds),
    )


__all__ = ["column", "price_pair", "signed_money", "subject"]
