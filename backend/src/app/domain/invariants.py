"""Portfolio invariants (ADR-E D-4) — exact equality, one documented tolerance.

The first three checks are **exact** ``Decimal`` comparisons with no epsilon:
an epsilon would hide exactly the float contamination ``Decimal`` is here to
prevent. The weights sum is the sole permitted tolerance, because a weight is
a division and the quotients cannot be expected to add back to exactly one.

Every failure names the offending holding and prints both sides of the
comparison — an invariant failure that says only "validation failed" is
unactionable against a multi-holding portfolio.
"""

from collections.abc import Sequence
from datetime import date
from decimal import Decimal
from typing import Final, NoReturn

from app.domain.errors import PortfolioInvariantError
from app.domain.holdings import Holding
from app.domain.lots import TaxLot
from app.domain.money import ONE, ZERO

WEIGHT_TOLERANCE: Final[Decimal] = Decimal("0.0001")


def _reject(symbol: str, rule: str, expected: Decimal, actual: Decimal) -> NoReturn:
    """Raise naming the holding, the broken rule and both sides.

    Raises:
        PortfolioInvariantError: Always — this helper only formats the failure.
    """
    msg = f"holding {symbol}: {rule}; expected {expected}, got {actual}"
    raise PortfolioInvariantError(msg)


def validate_holding(
    holding: Holding, *, lots: Sequence[TaxLot], price: Decimal
) -> None:
    """Check one holding against its open lots and the reference price.

    Args:
        holding: The aggregated position to check.
        lots: The open lots of that symbol.
        price: The current reference price of that symbol.

    Raises:
        PortfolioInvariantError: When quantity, cost basis or market value
            disagrees with the lots or the price.
    """
    quantity = sum((lot.quantity for lot in lots), ZERO)
    if holding.quantity != quantity:
        _reject(
            holding.symbol,
            "quantity must equal the sum of its open lot quantities",
            quantity,
            holding.quantity,
        )
    cost_basis = sum((lot.cost_basis for lot in lots), ZERO)
    if holding.cost_basis != cost_basis:
        _reject(
            holding.symbol,
            "cost_basis must equal the sum of its lot cost bases",
            cost_basis,
            holding.cost_basis,
        )
    market_value = holding.quantity * price
    if holding.market_value != market_value:
        _reject(
            holding.symbol,
            "market_value must equal quantity times price",
            market_value,
            holding.market_value,
        )


def validate_lot_dates(lots: Sequence[TaxLot], *, as_of: date) -> None:
    """Check that no lot was acquired after ``as_of``.

    Args:
        lots: The lots to check.
        as_of: The instant the portfolio is read at, as a date.

    Raises:
        PortfolioInvariantError: When a lot lies in the future.
    """
    for lot in lots:
        if lot.acquired_on > as_of:
            msg = (
                f"holding {lot.symbol}: lot {lot.lot_id} was acquired "
                f"{lot.acquired_on.isoformat()}, after as_of {as_of.isoformat()}"
            )
            raise PortfolioInvariantError(msg)


def validate_weights(holdings: Sequence[Holding]) -> None:
    """Check that the portfolio weights add up to one.

    Args:
        holdings: Every holding of the portfolio.

    Raises:
        PortfolioInvariantError: When the sum leaves ``WEIGHT_TOLERANCE``.
    """
    total = sum((holding.weight for holding in holdings), ZERO)
    if abs(total - ONE) > WEIGHT_TOLERANCE:
        msg = (
            f"portfolio weights must sum to 1 within {WEIGHT_TOLERANCE}, "
            f"got {total} across {len(holdings)} holding(s)"
        )
        raise PortfolioInvariantError(msg)


__all__ = [
    "WEIGHT_TOLERANCE",
    "validate_holding",
    "validate_lot_dates",
    "validate_weights",
]
