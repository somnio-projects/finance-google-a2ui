from datetime import timedelta

import httpx
import pytest

from app.auth.providers.jwks import JwksKeyResolver
from app.core.errors import DependencyUnavailableError
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW
from tests.unit.auth.rsa_fixture import JWKS, KID, rs256_token

JWKS_URL = "https://issuer.test/.well-known/jwks.json"


class CountingTransport(httpx.MockTransport):
    """Mock transport that counts how many times the JWKS was fetched."""

    def __init__(self, *, status: int = 200) -> None:
        self.calls = 0
        self._status = status
        super().__init__(self._handle)

    def _handle(self, request: httpx.Request) -> httpx.Response:
        self.calls += 1
        return httpx.Response(self._status, json=JWKS)


async def test_key_for_fetches_once_within_ttl_and_refreshes_after() -> None:
    clock = FixedClock(FROZEN_NOW)
    transport = CountingTransport()
    async with httpx.AsyncClient(transport=transport) as http:
        resolver = JwksKeyResolver(
            jwks_url=JWKS_URL, clock=clock, ttl=timedelta(minutes=5), http=http
        )
        token = rs256_token(subject="s", now=FROZEN_NOW)
        key = await resolver.key_for(token)
        await resolver.key_for(token)
        assert key.key_id == KID
        assert transport.calls == 1
        clock._instant = FROZEN_NOW + timedelta(minutes=6)
        await resolver.key_for(token)
        assert transport.calls == 2


async def test_key_for_unknown_kid_raises_key_error() -> None:
    async with httpx.AsyncClient(transport=CountingTransport()) as http:
        resolver = JwksKeyResolver(
            jwks_url=JWKS_URL, clock=FixedClock(FROZEN_NOW), http=http
        )
        with pytest.raises(KeyError):
            await resolver.key_for(rs256_token(subject="s", now=FROZEN_NOW, kid="nope"))


async def test_key_for_http_failure_becomes_dependency_unavailable() -> None:
    async with httpx.AsyncClient(transport=CountingTransport(status=503)) as http:
        resolver = JwksKeyResolver(
            jwks_url=JWKS_URL, clock=FixedClock(FROZEN_NOW), http=http
        )
        with pytest.raises(DependencyUnavailableError, match="identity provider"):
            await resolver.key_for(rs256_token(subject="s", now=FROZEN_NOW))


async def test_key_for_creates_and_closes_its_own_client(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    closed: list[bool] = []
    real_client = httpx.AsyncClient

    def factory(*args: object, **kwargs: object) -> httpx.AsyncClient:
        client = real_client(transport=CountingTransport())
        original = client.aclose

        async def aclose() -> None:
            closed.append(True)
            await original()

        client.aclose = aclose  # type: ignore[method-assign]
        return client

    monkeypatch.setattr("app.auth.providers.jwks.httpx.AsyncClient", factory)
    resolver = JwksKeyResolver(jwks_url=JWKS_URL, clock=FixedClock(FROZEN_NOW))
    await resolver.key_for(rs256_token(subject="s", now=FROZEN_NOW))
    assert closed == [True]
