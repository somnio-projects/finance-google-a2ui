"""Display shaping for ``simulate_sale`` (spec 0013 §3).

Split out of the tool module along the same seam the holdings tool uses:
**what the answer is** stays with the tool, **how it reads** lives here. Every
function is pure and returns nothing but strings, tokens and counts, so "did a
raw number escape to the model?" is a question about this one file.

It registers no tool; ``load_tools()`` imports it and nothing happens
(spec 0006 AC-7).
"""

from collections.abc import Mapping
from decimal import Decimal

from app.agent.tools.ratios import return_display
from app.core.display import (
    money_display,
    price_display,
    quantity_display,
)
from app.core.signed_display import (
    signed_money_display,
)
from app.core.trend import trend_of
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.terms import LotTerm


def lot_row(row: LotConsumption) -> Mapping[str, object]:
    """Render one consumed lot for the tax-lot comparator.

    Args:
        row: What the sale took out of one lot.

    Returns:
        The row the model copies. ``term`` and ``trend`` are UI tokens and
        ``fullySold`` a flag; every figure is a display string.
    """
    return {
        "lotId": row.lot_id,
        "acquiredOnDisplay": row.acquired_on.isoformat(),
        "term": row.term.value,
        "quantityDisplay": quantity_display(row.quantity, trim=True),
        "costBasisDisplay": money_display(row.cost_basis),
        "proceedsDisplay": money_display(row.proceeds),
        "gainLossDisplay": signed_money_display(row.gain_loss),
        "trend": trend_of(row.gain_loss),
        "fullySold": row.exhausted,
    }


def summary(result: SaleSimulation, *, method: str) -> Mapping[str, object]:
    """Render the scenario card: what the sale raises and what it realises.

    Args:
        result: The simulation, straight from the domain.
        method: The lot-selection method the caller asked for, echoed back so
            a reader of the payload alone can tell which comparison this is.

    Returns:
        The summary block. The short/long split is read from the consumed
        lots, so it cannot disagree with the rows beside it.
    """
    return {
        "symbol": result.symbol,
        "lotMethod": method,
        "priceDisplay": price_display(result.price),
        "quantityDisplay": quantity_display(result.quantity, trim=True),
        "proceedsDisplay": money_display(result.proceeds),
        "costBasisDisplay": money_display(result.cost_basis),
        "realizedPlDisplay": signed_money_display(result.realized_pl),
        "realizedPlPctDisplay": return_display(result.realized_pl, result.cost_basis),
        "shortTermPlDisplay": signed_money_display(result.pl_in(LotTerm.SHORT)),
        "longTermPlDisplay": signed_money_display(result.pl_in(LotTerm.LONG)),
        "shortTermLots": result.lots_in(LotTerm.SHORT),
        "longTermLots": result.lots_in(LotTerm.LONG),
        "trend": trend_of(result.realized_pl),
    }


def remaining(result: SaleSimulation) -> Mapping[str, object]:
    """Render what the position looks like after the sale.

    Args:
        result: The simulation, straight from the domain.

    Returns:
        The leftover position — the half of the comparator that makes it a
        decision rather than a receipt.
    """
    return {
        "count": result.remaining_lots,
        "quantityDisplay": quantity_display(result.remaining_quantity, trim=True),
        "costBasisDisplay": money_display(result.remaining_cost_basis),
        "marketValueDisplay": money_display(result.remaining_market_value()),
    }


def scenario(result: SaleSimulation, *, method: str) -> Mapping[str, object]:
    """Name the simulated sale as ``taxlots.table.v1`` declares its options.

    Args:
        result: The simulation, so the scenario named is the one that was
            actually costed — a dollar-sized ask has already become units.
        method: The lot-selection method, echoed as the view declares it.

    Returns:
        The options of the render intent. ``quantity`` is formatted with
        ``:f`` rather than ``str()``: a ``Decimal`` quantized to eight places
        renders as ``1E-8`` in scientific notation, which the view's bounded
        size pattern rejects. Spec 0015 AC-13 validates this against the
        projection's own options model rather than trusting the shape here.
    """
    return {
        "symbol": result.symbol,
        "quantity": f"{result.quantity:f}",
        "lot_method": method,
    }


def too_small(
    *, symbol: str, requested: Decimal, held: Decimal
) -> Mapping[str, object]:
    """Render an over-sell as an answer the model can read out (OD-3).

    Args:
        symbol: The canonical ticker the sale named.
        requested: Units the sale asked to dispose of.
        held: Units the position actually holds.

    Returns:
        A structured refusal carrying both quantities pre-formatted, so the
        model states the shortfall instead of inventing it. A partial fill
        would answer a question nobody asked.
    """
    return {
        "error": "position-too-small",
        "symbol": symbol,
        "requestedDisplay": quantity_display(requested, trim=True),
        "heldDisplay": quantity_display(held, trim=True),
    }


__all__ = ["lot_row", "remaining", "scenario", "summary", "too_small"]
