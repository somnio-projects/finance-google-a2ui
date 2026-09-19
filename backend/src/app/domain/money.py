"""``Decimal`` money and quantity types for the portfolio domain (ADR-E D-1/D-5).

Every monetary amount, price, quantity and cost basis in this package is a
``decimal.Decimal`` parsed from a **string**. A ``float`` is rejected at the
model boundary rather than coerced: ``Decimal(0.1)`` is
``0.1000000000000000055511151231257827...``, and a value that has already been
through a float cannot be repaired by ``Decimal(str(x))`` afterwards — the
precision is gone before this package ever sees it.

``int`` is accepted (it is exact). Rounding happens only at display
(ADR-E D-3), never here; this module is the only one in the package that
mentions ``float`` at all.
"""

from decimal import Decimal
from typing import Annotated, Final

from pydantic import BeforeValidator

ZERO: Final[Decimal] = Decimal(0)
ONE: Final[Decimal] = Decimal(1)


def reject_float(value: object) -> object:
    """Return ``value`` untouched unless it is a ``float``.

    Args:
        value: The raw value pydantic is about to parse into a ``Decimal``.

    Returns:
        The same value, for pydantic to parse.

    Raises:
        ValueError: When ``value`` is a ``float`` — pass a string instead.
    """
    if isinstance(value, float):
        msg = f"float is not accepted for a money field, pass a string: {value!r}"
        raise ValueError(msg)
    return value


Money = Annotated[Decimal, BeforeValidator(reject_float)]
Quantity = Annotated[Decimal, BeforeValidator(reject_float)]

__all__ = ["ONE", "ZERO", "Money", "Quantity", "reject_float"]
