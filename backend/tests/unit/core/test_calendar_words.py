"""The timeline's vocabulary, per locale (spec 0028 OD-4)."""

from datetime import date

import pytest

from app.core.calendar_words import (
    MONTHS,
    WEEKDAYS,
    month_day_label,
    month_year_heading,
    weekday_label,
)
from app.core.locales import LOCALE_FORMATS


def test_every_money_locale_has_a_calendar() -> None:
    assert set(MONTHS) == set(LOCALE_FORMATS) == set(WEEKDAYS)
    assert all(len(months) == 12 for months in MONTHS.values())
    assert all(len(days) == 7 for days in WEEKDAYS.values())


@pytest.mark.parametrize(
    ("locale", "heading", "day", "weekday"),
    [
        ("en-US", "SEPTEMBER 2026", "Sep 16", "Wed"),
        ("es-AR", "SEPTIEMBRE 2026", "sep 16", "mié"),
        ("de-DE", "SEPTEMBER 2026", "Sep 16", "Mi"),
    ],
)
def test_the_words_follow_the_locale(
    locale: str, heading: str, day: str, weekday: str
) -> None:
    when = date(2026, 9, 16)
    assert month_year_heading(when, locale=locale) == heading
    assert month_day_label(when, locale=locale) == day
    assert weekday_label(when, locale=locale) == weekday
