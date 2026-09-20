"""Return on cost, as the string a tool payload carries (spec 0013 OD-6).

One function, shared by every tool that reports a profit as a percentage of
what was paid. It was private to ``holdings_rows`` until ``simulate_sale``
needed the same three lines; a second copy is a second place for the
``None`` case to be answered differently.

The ratio itself is ``app.domain.returns.return_on_cost`` — the finance lives
in the domain, and this only decides how it reads. It registers no tool;
``load_tools()`` imports it and nothing happens (spec 0006 AC-7).
"""

from decimal import Decimal

from app.core.display import percentage_display
from app.domain.returns import return_on_cost


def return_display(profit: Decimal, cost_basis: Decimal) -> str | None:
    """Return the profit as a percentage of cost, or ``None`` when undefined.

    Args:
        profit: The gain or loss, realised or unrealised, signed.
        cost_basis: What the units cost; never negative.

    Returns:
        A percentage string such as ``"+17.27%"``, or ``None`` when the cost
        basis is zero. ``"0.00%"`` would report a flat position that is in
        fact infinitely profitable (spec 0011 OD-2), so the field is nullable
        and the tool descriptions tell the model to give the dollar figure
        when it is missing.
    """
    ratio = return_on_cost(profit, cost_basis)
    if ratio is None:
        return None
    return percentage_display(ratio)


__all__ = ["return_display"]
