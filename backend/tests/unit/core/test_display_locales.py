"""AC-4, AC-5 — the single Decimal → string boundary (ADR-E D-2/D-3).

The client binds these strings verbatim, so a wrong separator or a wrong
rounding mode is a visible bug in the demo, not a style question.
"""

from decimal import Decimal

import pytest

from app.core.display import money_display, percentage_display, quantity_display
from app.core.locales import quantize


@pytest.mark.parametrize(
    ("locale", "expected"),
    [
        ("en-US", "$18,060.00"),
        ("es-AR", "US$ 18.060,00"),
        ("de-DE", "18.060,00 $"),
    ],
    ids=["en-US", "es-AR", "de-DE"],
)
def test_money_display_follows_the_requested_locale(locale: str, expected: str) -> None:
    assert money_display(Decimal("18060.00"), locale=locale) == expected


def test_money_display_keeps_the_sign_outside_the_currency() -> None:
    assert money_display(Decimal("-1234.5")) == "-$1,234.50"


def test_money_display_without_decimals_drops_the_separator() -> None:
    assert money_display(Decimal("1234.56"), precision=0) == "$1,235"


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (Decimal("2.345"), "2.34"),
        (Decimal("2.355"), "2.36"),
        (Decimal("2.365"), "2.36"),
    ],
    ids=["half-down-to-even", "half-up-to-even", "half-down-to-even-again"],
)
def test_quantize_rounds_half_even(value: Decimal, expected: str) -> None:
    assert quantize(value, precision=2) == Decimal(expected)


def test_percentage_display_scales_a_ratio_and_appends_the_sign() -> None:
    assert percentage_display(Decimal("0.31244")) == "31.24%"
    assert percentage_display(Decimal("-0.055")) == "-5.50%"


def test_percentage_display_uses_the_locale_separator() -> None:
    assert percentage_display(Decimal("0.3124"), locale="de-DE") == "31,24%"


def test_quantity_display_carries_eight_decimals_by_default() -> None:
    assert quantity_display(Decimal("0.6")) == "0.60000000"


def test_quantity_display_has_no_currency_marker() -> None:
    assert quantity_display(Decimal("12000"), precision=2) == "12,000.00"
