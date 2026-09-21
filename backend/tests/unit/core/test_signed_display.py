"""Spec 0026 — a change leads with its sign; a flat one claims nothing."""

from decimal import Decimal

import pytest

from app.core.signed_display import signed_money_display, signed_percentage_display


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (Decimal("3240.18"), "+$3,240.18"),
        (Decimal("-1674"), "-$1,674.00"),
        (Decimal("0"), "$0.00"),
        (Decimal("0.004"), "$0.00"),
    ],
    ids=["gain", "loss", "flat", "rounds_flat"],
)
def test_signed_money_display(value: Decimal, expected: str) -> None:
    assert signed_money_display(value) == expected


@pytest.mark.parametrize(
    ("ratio", "precision", "expected"),
    [
        (Decimal("0.006755"), 2, "+0.68%"),
        (Decimal("0.042"), 1, "+4.2%"),
        (Decimal("-0.023"), 1, "-2.3%"),
        (Decimal("0"), 1, "0.0%"),
        (Decimal("0.0004"), 1, "0.0%"),
    ],
    ids=["hero", "mover_up", "mover_down", "flat", "rounds_flat"],
)
def test_signed_percentage_display(
    ratio: Decimal, precision: int, expected: str
) -> None:
    assert signed_percentage_display(ratio, precision=precision) == expected


def test_signed_percentage_honours_the_locale() -> None:
    assert signed_percentage_display(
        Decimal("0.0068"), precision=2, locale="de-DE"
    ) == ("+0,68%")
