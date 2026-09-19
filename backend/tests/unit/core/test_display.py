"""Spec 0006 AC-8 — the single Decimal → display boundary (ADR-E D-2/D-3)."""

from decimal import Decimal

import pytest

from app.core.display import (
    money_display,
    percentage_display,
    quantity_display,
    signed_money_display,
)


@pytest.mark.parametrize(
    ("amount", "expected"),
    [
        (Decimal("64250"), "$64,250.00"),
        (Decimal("0"), "$0.00"),
        (Decimal("1234567.891"), "$1,234,567.89"),
        (Decimal("-1234.56"), "-$1,234.56"),
        (Decimal("-0.001"), "$0.00"),
        (Decimal("0.125"), "$0.12"),
        (Decimal("0.135"), "$0.14"),
    ],
    ids=[
        "thousands_separator",
        "zero",
        "millions_rounded_down",
        "negative_sign_leads",
        "negative_rounding_to_zero_loses_the_sign",
        "half_even_rounds_down_to_even",
        "half_even_rounds_up_to_even",
    ],
)
def test_money_display_formats_usd_to_two_places(
    amount: Decimal, expected: str
) -> None:
    assert money_display(amount) == expected


@pytest.mark.parametrize(
    ("amount", "expected"),
    [
        (Decimal("1234.5"), "+$1,234.50"),
        (Decimal("-1234.5"), "-$1,234.50"),
        (Decimal("0"), "$0.00"),
    ],
    ids=["gain_is_signed", "loss_keeps_its_minus", "flat_carries_no_sign"],
)
def test_signed_money_display_marks_gains_explicitly(
    amount: Decimal, expected: str
) -> None:
    assert signed_money_display(amount) == expected


@pytest.mark.parametrize(
    ("quantity", "expected"),
    [
        (Decimal("0.75000000"), "0.75"),
        (Decimal("1000"), "1000"),
        (Decimal("0"), "0"),
        (Decimal("0.123456789"), "0.12345679"),
    ],
    ids=["trailing_zeros_trimmed", "integer", "zero", "rounded_to_eight_places"],
)
def test_quantity_display_trimmed_drops_trailing_zeros(
    quantity: Decimal, expected: str
) -> None:
    assert quantity_display(quantity, trim=True) == expected


@pytest.mark.parametrize(
    ("ratio", "expected"),
    [
        (Decimal("0.425"), "42.50%"),
        (Decimal("1"), "100.00%"),
        (Decimal("0"), "0.00%"),
        (Decimal("0.123456"), "12.35%"),
    ],
    ids=["fraction", "whole", "zero", "rounded_to_two_places"],
)
def test_percentage_display_renders_a_ratio_as_a_percentage(
    ratio: Decimal, expected: str
) -> None:
    assert percentage_display(ratio) == expected
