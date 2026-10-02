"""AC-5 — money is Decimal end to end and a float never gets in."""

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.domain.money import ONE, ZERO, reject_float
from app.domain.prices import PricePoint
from tests.conftest import FROZEN_NOW


def _price_point(price: object) -> PricePoint:
    """Build a point the way raw data would arrive, bypassing static typing."""
    return PricePoint.model_validate(
        {"symbol": "BTC", "observed_on": FROZEN_NOW.date(), "price": price}
    )


def test_money_field_rejects_float() -> None:
    with pytest.raises(ValidationError, match="float is not accepted"):
        _price_point(64250.00)


def test_reject_float_names_the_offending_value() -> None:
    with pytest.raises(ValueError, match=r"pass a string: 0\.1"):
        reject_float(0.1)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("64250.00", Decimal("64250.00")),
        (Decimal("34.22"), Decimal("34.22")),
        (7, Decimal(7)),
    ],
    ids=["string", "decimal", "int"],
)
def test_money_field_accepts_string_int_and_decimal(
    raw: object, expected: Decimal
) -> None:
    point = _price_point(raw)
    assert point.price == expected
    assert isinstance(point.price, Decimal)


def test_money_constants_are_exact_decimals() -> None:
    assert ZERO == Decimal(0)
    assert ONE == Decimal(1)
