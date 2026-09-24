"""Spec 0024 §7 — the `date` → display-string boundary.

A date is the one value in a payload that had no formatter, so it shipped as
an ISO string and the client drew it. These tests are about the two things
that can go wrong once it has one: a locale the figures accept and the dates
do not, and a field order that reads as a different day.
"""

from datetime import date

import pytest

from app.core.dates import DATE_FORMATS, date_display
from app.core.locales import LOCALE_FORMATS

LOT_DAY = date(2025, 1, 13)


def test_every_locale_the_figures_accept_can_write_a_date() -> None:
    """Two declarations of one locale set, compared rather than assumed.

    `DisplayOptions.locale` is validated against `LOCALE_FORMATS`, so a locale
    present there and missing here is a `KeyError` raised from inside a pure
    presenter — on a render that had already validated its options.
    """
    assert set(DATE_FORMATS) == set(LOCALE_FORMATS)


@pytest.mark.parametrize(
    ("locale", "expected"),
    [
        ("en-US", "01/13/2025"),
        ("es-AR", "13/01/2025"),
        ("de-DE", "13.01.2025"),
    ],
    ids=["en-US-month-first", "es-AR-day-first", "de-DE-dots"],
)
def test_the_field_order_and_separator_follow_the_locale(
    locale: str, expected: str
) -> None:
    """The half that actually misleads a reader: `01/13` and `13/01`."""
    assert date_display(LOT_DAY, locale=locale) == expected


def test_the_default_locale_needs_no_argument() -> None:
    """`en-US`, the same default every other display helper carries."""
    assert date_display(LOT_DAY) == "01/13/2025"


@pytest.mark.parametrize(
    ("day", "expected"),
    [
        (date(2025, 9, 5), "09/05/2025"),
        (date(999, 12, 31), "12/31/0999"),
    ],
    ids=["single-digit-day-and-month", "three-digit-year"],
)
def test_every_field_is_zero_padded_to_its_own_width(day: date, expected: str) -> None:
    """A `9/5/2025` beside a `09/05/2025` is two spellings of one day."""
    assert date_display(day, locale="en-US") == expected
