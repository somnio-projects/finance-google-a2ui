"""JWKS fetching with a small time-based cache.

Separated from the OIDC verifier so key retrieval can be tested and swapped
(for example, a static key set in tests) without touching verification.
"""

from datetime import datetime, timedelta
from typing import Any, Protocol

import httpx
import jwt

from app.core.errors import DependencyUnavailableError
from app.core.protocols import Clock


class KeyResolver(Protocol):
    """Resolve the verification key for a token."""

    async def key_for(self, token: str) -> jwt.PyJWK:
        """Return the key matching the token's ``kid`` header."""
        ...


class JwksKeyResolver:
    """Fetch a JWKS document over HTTPS and cache it for ``ttl``."""

    def __init__(
        self,
        *,
        jwks_url: str,
        clock: Clock,
        ttl: timedelta = timedelta(hours=1),
        http: httpx.AsyncClient | None = None,
    ) -> None:
        """Configure the resolver; ``http`` is injectable for tests."""
        self._url = jwks_url
        self._clock = clock
        self._ttl = ttl
        self._http = http
        self._keys: dict[str, Any] | None = None
        self._fetched_at: datetime | None = None

    def _is_fresh(self) -> bool:
        if self._keys is None or self._fetched_at is None:
            return False
        return self._clock.now() - self._fetched_at < self._ttl

    async def _fetch(self) -> dict[str, Any]:
        client = self._http or httpx.AsyncClient(timeout=5.0)
        try:
            response = await client.get(self._url)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as exc:
            raise DependencyUnavailableError("identity provider unreachable") from exc
        finally:
            if self._http is None:
                await client.aclose()

    async def key_for(self, token: str) -> jwt.PyJWK:
        """Return the JWK for the token's ``kid``, refreshing the cache if stale."""
        if not self._is_fresh():
            self._keys = await self._fetch()
            self._fetched_at = self._clock.now()
        key_set = jwt.PyJWKSet.from_dict(self._keys or {})
        header = jwt.get_unverified_header(token)
        return key_set[header.get("kid", "")]


__all__ = ["JwksKeyResolver", "KeyResolver"]
