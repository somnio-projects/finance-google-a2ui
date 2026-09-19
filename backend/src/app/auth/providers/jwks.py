"""JWKS fetching with a small time-based cache.

Separated from the OIDC verifier so key retrieval can be tested and swapped
(for example, a static key set in tests) without touching verification. The
provider's JSON is parsed into ``JwksDocument`` before PyJWT ever sees it.
"""

from datetime import datetime, timedelta
from typing import Protocol

import httpx
import jwt
from pydantic import BaseModel, ConfigDict, Field

from app.core.errors import DependencyUnavailableError
from app.core.protocols import Clock


class JwksKey(BaseModel):
    """One JWK (RFC 7517). Algorithm-specific members stay as extras."""

    model_config = ConfigDict(frozen=True, extra="allow")

    kty: str = Field(min_length=1)
    kid: str | None = None


class JwksDocument(BaseModel):
    """The JWK Set a provider publishes at its ``jwks_uri``."""

    model_config = ConfigDict(frozen=True)

    keys: list[JwksKey]


class KeyResolver(Protocol):
    """Resolve the verification key for a token (command, then query)."""

    async def ensure_fresh(self) -> None:
        """Refresh the key material when it is stale."""
        ...

    def key_for(self, token: str) -> jwt.PyJWK:
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
        self._document = JwksDocument(keys=[])
        self._fetched_at: datetime | None = None

    def _is_fresh(self) -> bool:
        if self._fetched_at is None:
            return False
        return self._clock.now() - self._fetched_at < self._ttl

    async def _fetch(self) -> JwksDocument:
        client = self._http or httpx.AsyncClient(timeout=5.0)
        try:
            response = await client.get(self._url)
            response.raise_for_status()
            return JwksDocument.model_validate(response.json())
        except (httpx.HTTPError, ValueError) as exc:
            # ValueError: not JSON, or (pydantic ValidationError) not a JWK Set.
            raise DependencyUnavailableError("identity provider unreachable") from exc
        finally:
            if self._http is None:
                await client.aclose()

    async def ensure_fresh(self) -> None:
        """Command: replace the cached document once the TTL has elapsed."""
        if self._is_fresh():
            return
        self._document = await self._fetch()
        self._fetched_at = self._clock.now()

    def _key_set(self) -> jwt.PyJWKSet:
        """Query: the cached document as a PyJWT key set."""
        return jwt.PyJWKSet.from_dict(self._document.model_dump(exclude_none=True))

    def key_for(self, token: str) -> jwt.PyJWK:
        """Query: the JWK for the token's ``kid`` from the cached document."""
        header = jwt.get_unverified_header(token)
        return self._key_set()[header.get("kid", "")]


__all__ = ["JwksDocument", "JwksKey", "JwksKeyResolver", "KeyResolver"]
