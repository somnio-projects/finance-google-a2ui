"""Month and weekday names, per locale — the words a timeline prints.

``dates.py`` deliberately prints digits, because a component's dates are
figures. A timeline's *headings* are words — the design says ``SEPTEMBER
2026``, ``Wed``, ``Sep 12`` — so the vocabulary lives here, once, keyed by the
same locales the figures accept (spec 0028 OD-4). Nothing in the client
spells a month.
"""

from datetime import date
from typing import Final

MONTHS: Final[dict[str, tuple[str, ...]]] = {
    "en-US": (
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ),
    "es-AR": (
        "enero",
        "febrero",
        "marzo",
        "abril",
        "mayo",
        "junio",
        "julio",
        "agosto",
        "septiembre",
        "octubre",
        "noviembre",
        "diciembre",
    ),
    "de-DE": (
        "Januar",  # codespell:ignore
        "Februar",  # codespell:ignore
        "März",
        "April",
        "Mai",
        "Juni",  # codespell:ignore
        "Juli",  # codespell:ignore
        "August",
        "September",
        "Oktober",  # codespell:ignore
        "November",
        "Dezember",  # codespell:ignore
    ),
}
WEEKDAYS: Final[dict[str, tuple[str, ...]]] = {
    "en-US": ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"),
    "es-AR": ("lun", "mar", "mié", "jue", "vie", "sáb", "dom"),  # codespell:ignore
    "de-DE": ("Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"),
}


def month_year_heading(value: date, *, locale: str) -> str:
    """``SEPTEMBER 2026`` — the timeline's section heading for a month."""
    return f"{MONTHS[locale][value.month - 1]} {value.year}".upper()


def month_day_label(value: date, *, locale: str) -> str:
    """``Sep 12`` — the short day a row prints inside the month."""
    return f"{MONTHS[locale][value.month - 1][:3]} {value.day}"


def weekday_label(value: date, *, locale: str) -> str:
    """``Wed`` — the day a row prints inside the current week."""
    return WEEKDAYS[locale][value.weekday()]


__all__ = [
    "MONTHS",
    "WEEKDAYS",
    "month_day_label",
    "month_year_heading",
    "weekday_label",
]
