from datetime import UTC, datetime

import pytest

from app.helpers.clock import FixedClock, SystemClock


def test_system_clock_returns_aware_utc_now() -> None:
    now = SystemClock().now()
    assert now.tzinfo is UTC
    assert abs((datetime.now(tz=UTC) - now).total_seconds()) < 5


def test_fixed_clock_returns_the_frozen_instant() -> None:
    instant = datetime(2026, 1, 1, tzinfo=UTC)
    assert FixedClock(instant).now() is instant


def test_fixed_clock_rejects_naive_datetime() -> None:
    with pytest.raises(ValueError, match="aware datetime"):
        FixedClock(datetime(2026, 1, 1))
