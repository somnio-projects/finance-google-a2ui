from datetime import timedelta

from app.helpers.clock import FixedClock
from app.services.feature_flag_cache import FeatureFlagCache
from tests.conftest import FROZEN_NOW


def test_cache_returns_none_for_unknown_key(clock: FixedClock) -> None:
    cache = FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock)
    assert cache.get("nope") is None


def test_cache_serves_value_inside_ttl_and_expires_after(clock: FixedClock) -> None:
    cache = FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock)
    cache.put("identity.audit", False)
    clock.advance(timedelta(seconds=14))
    assert cache.get("identity.audit") is False
    clock.advance(timedelta(seconds=1))
    assert cache.get("identity.audit") is None
    assert clock.now() == FROZEN_NOW + timedelta(seconds=15)


def test_cache_invalidate_forgets_key_and_tolerates_missing(clock: FixedClock) -> None:
    cache = FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock)
    cache.put("k", True)
    cache.invalidate("k")
    cache.invalidate("k")
    assert cache.get("k") is None
