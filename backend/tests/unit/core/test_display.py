"""Spec 0006 AC-8 — the single Decimal → display boundary (ADR-E D-2/D-3)."""

from decimal import Decimal

import pytest

from app.core.display import (
    MONEY_PRECISION,
    money_display,
    percentage_display,
    price_display,
    quantity_display,
    signed_money_display,
)
from app.core.locales import quantize


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


@pytest.mark.parametrize(
    ("price", "expected"),
    [
        (Decimal("64250.00"), "$64,250.00"),
        (Decimal("11.85"), "$11.85"),
        (Decimal("0.1273"), "$0.1273"),
        (Decimal("4.2150"), "$4.2150"),
    ],
    ids=[
        "a_price_exact_in_cents_stays_in_cents",
        "two_places_are_enough_here_too",
        "a_sub_cent_price_keeps_its_own_digits",
        "a_finer_price_is_shown_at_the_full_price_precision",
    ],
)
def test_price_display_carries_the_precision_the_price_is_quoted_to(
    price: Decimal, expected: str
) -> None:
    """Spec 0013 OD-4 — a price is the figure a reader multiplies by."""
    assert price_display(price) == expected


def test_a_sub_cent_price_would_not_tie_out_if_it_were_flattened() -> None:
    """The bug this exists to prevent, written as the arithmetic itself.

    Twelve thousand DOGE at $0.1273 is $1,527.60. Rounded to cents first, the
    same multiplication reads $1,560.00 — a $32.40 gap between two figures in
    one payload block.
    """
    price = Decimal("0.1273")
    units = Decimal(12000)

    assert money_display(units * price) == "$1,527.60"
    assert price_display(price) == "$0.1273"
    assert money_display(units * quantize(price, precision=MONEY_PRECISION)) != (
        money_display(units * price)
    )
