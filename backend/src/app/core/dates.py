"""The single ``date`` → display-string boundary (ADR-E D-2, spec 0024 §7).

``display.py`` does this for every figure; a **date** had no equivalent, so
``taxlots.table.v1`` shipped ``acquired_on`` as a bare ISO string and the
client drew it — ``2025-01-13`` on a card whose every other value is
pre-formatted. Re-spelling it in the client is formatting, which N-4 forbids
and `frontend`'s own layering test fails on (`intl` is absent from `lib/`), so
the date was rendered as it arrived. That is the ADR-E violation this module
closes: the string a reader sees is written here, once, beside the raw value.

It lives in ``core`` for the reason ``display`` does — both ``app.agent`` and
``app.presentation`` may need it and neither may import the other — and it
reads ``LOCALE_FORMATS`` so a locale the money formatter accepts is exactly a
locale this one accepts.

**Digits, not month names.** A ``Mar 12, 2021`` needs a twelve-word vocabulary
in every locale the view offers, and an English ``Mar`` inside a ``de-DE``
payload would be a second defect rather than a nicer one. The order and the
separator are per-locale, which is the part that actually misleads a reader:
``01/13/2025`` and ``13.01.2025`` are the same day, and ``13/01`` read as
``en-US`` is not a day at all.
"""

from datetime import date
from typing import Final

from app.core.locales import DEFAULT_LOCALE

#: locale → (field order, separator). Keyed by the same locales as
#: ``LOCALE_FORMATS``; a test compares the two key sets rather than a comment
#: claiming they agree.
DATE_FORMATS: Final[dict[str, tuple[tuple[str, str, str], str]]] = {
    "en-US": (("month", "day", "year"), "/"),
    "es-AR": (("day", "month", "year"), "/"),
    "de-DE": (("day", "month", "year"), "."),
}

_WIDTHS: Final[dict[str, int]] = {"day": 2, "month": 2, "year": 4}


def date_display(value: date, *, locale: str = DEFAULT_LOCALE) -> str:
    """Return a calendar day as the string the widget prints.

    Args:
        value: The day itself, exact and unformatted.
        locale: One of ``LOCALE_FORMATS`` — the same set the figures use.

    Returns:
        The day in that locale's field order and separator, zero-padded:
        ``"01/13/2025"`` for ``en-US``, ``"13.01.2025"`` for ``de-DE``.
    """
    order, separator = DATE_FORMATS[locale]
    fields = {"day": value.day, "month": value.month, "year": value.year}
    return separator.join(f"{fields[name]:0{_WIDTHS[name]}d}" for name in order)


__all__ = ["DATE_FORMATS", "date_display"]
