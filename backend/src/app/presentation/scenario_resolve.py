"""Turning a scenario comparison's two ``None`` defaults into a sale (spec 0017).

Split from ``scenario_options`` at the file budget when the options grew the
declared tax rates (spec 0051). That file's docstring argued the two belonged
together — *"the defaults are only honest if the rule behind each is written
next to the field"* — and the argument still holds; what changed is that one
file can no longer hold both. The field documents the rule and points here.
"""

from decimal import Decimal

from app.core.errors import ValidationFailedError
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.symbols import normalize_symbol
from app.presentation.scenario_options import ScenarioComparisonOptions


def _largest_position(portfolio: Portfolio) -> str:
    """Return the ticker whose open lots are worth the most at ``as_of``.

    Args:
        portfolio: The portfolio to read.

    Returns:
        The canonical ticker; ties break on ascending symbol, so the rule is
        total and the documented example is byte-stable.

    Raises:
        ValidationFailedError: When the portfolio holds no open tax lots at
            all, so there is no sale to compare (spec 0017 OD-5).
    """
    worth: dict[str, Decimal] = {}
    for lot in portfolio.lots:
        value = lot.market_value(portfolio.price(lot.symbol))
        worth[lot.symbol] = worth.get(lot.symbol, ZERO) + value
    if not worth:
        msg = "this portfolio holds no open tax lots to compare a sale against"
        raise ValidationFailedError(msg)
    return min(worth, key=lambda symbol: (-worth[symbol], symbol))


def resolve(
    portfolio: Portfolio, options: ScenarioComparisonOptions
) -> tuple[str, Decimal]:
    """Turn the caller's options into the one scenario every column shares.

    Args:
        portfolio: The data the defaults resolve against.
        options: The validated options.

    Returns:
        The canonical ticker and the units to sell (spec 0017 OD-2).

    Raises:
        ValidationFailedError: When the named position holds no open lots —
            there is nothing to compare, so nothing is rendered.
    """
    symbol = (
        normalize_symbol(options.symbol)
        if options.symbol
        else _largest_position(portfolio)
    )
    lots = portfolio.tax_lots(symbol)
    if not lots:
        msg = f"no open tax lots in {symbol} to compare a sale against"
        raise ValidationFailedError(msg)
    return symbol, options.quantity or min(lot.quantity for lot in lots)


__all__ = ["resolve"]
