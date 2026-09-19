"""AC-3 — lot term is derived from an injected ``as_of``, boundary included.

The documented rule (spec 0003 OD-4): long-term requires **strictly more than
365 days** held, so the anniversary itself is still short-term.
"""

from datetime import date, timedelta

import pytest

from app.domain.errors import PortfolioInvariantError
from app.domain.terms import LONG_TERM_DAYS, LotTerm, derive_term, holding_period_days
from tests.unit.domain.conftest import make_lot

AS_OF = date(2026, 9, 18)


@pytest.mark.parametrize(
    ("acquired_on", "expected"),
    [
        (AS_OF - timedelta(days=366), LotTerm.LONG),
        (AS_OF - timedelta(days=365), LotTerm.SHORT),
        (AS_OF - timedelta(days=364), LotTerm.SHORT),
        (AS_OF - timedelta(days=1), LotTerm.SHORT),
        (AS_OF, LotTerm.SHORT),
        (AS_OF - timedelta(days=800), LotTerm.LONG),
    ],
    ids=[
        "366d-long",
        "365d-boundary-short",
        "364d-short",
        "1d-short",
        "same-day-short",
        "800d-long",
    ],
)
def test_derive_term_classifies_holding_period(
    acquired_on: date, expected: LotTerm
) -> None:
    assert derive_term(acquired_on, as_of=AS_OF) is expected


def test_derive_term_on_a_leap_day_holds_the_boundary() -> None:
    acquired_on = date(2024, 2, 29)
    anniversary = date(2025, 2, 28)
    assert holding_period_days(acquired_on, as_of=anniversary) == LONG_TERM_DAYS
    assert derive_term(acquired_on, as_of=anniversary) is LotTerm.SHORT
    assert derive_term(acquired_on, as_of=date(2025, 3, 2)) is LotTerm.LONG


def test_holding_period_days_rejects_a_future_acquisition() -> None:
    with pytest.raises(PortfolioInvariantError, match="is in the future"):
        holding_period_days(AS_OF + timedelta(days=1), as_of=AS_OF)


def test_tax_lot_derives_its_term_rather_than_storing_it() -> None:
    lot = make_lot(days_before=400)
    assert "term" not in lot.model_dump()
    assert lot.term(lot.acquired_on + timedelta(days=365)) is LotTerm.SHORT
    assert lot.term(lot.acquired_on + timedelta(days=366)) is LotTerm.LONG
