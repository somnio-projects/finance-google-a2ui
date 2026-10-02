"""AC-10 — the generated price series is deterministic and ends at the price."""

from datetime import timedelta

import pytest

from app.domain.errors import SymbolNotFoundError, WindowOutOfRangeError
from app.domain.history import (
    HISTORY_DAYS,
    MAX_DRIFT_BP,
    drift_basis_points,
    price_history,
    price_on,
)
from app.domain.market import price_of
from app.domain.portfolio import Portfolio
from tests.conftest import FROZEN_NOW


def test_drift_is_zero_at_as_of_and_bounded_before_it() -> None:
    assert drift_basis_points("BTC", offset=0) == 0
    drifts = [drift_basis_points("BTC", offset=offset) for offset in range(1, 90)]
    assert all(abs(drift) <= MAX_DRIFT_BP for drift in drifts)
    assert len(set(drifts)) > 1


def test_price_on_the_as_of_day_equals_the_reference_price() -> None:
    assert price_on("btc", offset=0) == price_of("BTC")


def test_price_on_keeps_the_scale_of_the_reference_price() -> None:
    assert price_on("LINK", offset=5).as_tuple().exponent == -2


def test_price_history_is_ascending_and_deterministic() -> None:
    first = price_history("BTC", as_of=FROZEN_NOW.date())
    second = price_history("btc", as_of=FROZEN_NOW.date())
    assert first == second
    assert len(first) == HISTORY_DAYS
    assert [point.observed_on for point in first] == sorted(
        point.observed_on for point in first
    )
    assert first[-1].price == price_of("BTC")
    assert first[-1].observed_on == FROZEN_NOW.date()


def test_price_history_with_zero_points_is_empty() -> None:
    assert price_history("BTC", as_of=FROZEN_NOW.date(), points=0) == ()


def test_widening_the_window_leaves_existing_points_untouched(
    portfolio: Portfolio,
) -> None:
    narrow = portfolio.price_series("BTC", timedelta(days=7))
    wide = portfolio.price_series("BTC", timedelta(days=30))
    assert wide[-len(narrow) :] == narrow


@pytest.mark.parametrize(
    ("window", "expected"),
    [
        (timedelta(0), 1),
        (timedelta(hours=12), 1),
        (timedelta(days=7), 8),
        (timedelta(days=HISTORY_DAYS - 1), HISTORY_DAYS),
        (timedelta(days=900), HISTORY_DAYS),
    ],
    ids=["zero", "sub-day", "seven-days", "exact-history", "wider-than-history"],
)
def test_price_series_window_sizes(
    portfolio: Portfolio, window: timedelta, expected: int
) -> None:
    series = portfolio.price_series("BTC", window)
    assert len(series) == expected
    assert series[-1].price == portfolio.price("BTC")


def test_price_series_rejects_a_negative_window(portfolio: Portfolio) -> None:
    with pytest.raises(WindowOutOfRangeError, match="must not be negative"):
        portfolio.price_series("BTC", timedelta(days=-1))


def test_price_series_of_an_unknown_symbol_raises(portfolio: Portfolio) -> None:
    with pytest.raises(SymbolNotFoundError, match="'NOPE'"):
        portfolio.price_series("nope", timedelta(days=7))
