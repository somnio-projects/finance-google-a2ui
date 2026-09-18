"""Shared-secret (HS256) JWT verifier.

Intended for service-to-service tokens and local development. Production
user traffic should use ``OidcTokenVerifier`` so no signing secret lives on
this service (SOC 2 CC6.1 — least privilege for key material).
"""

import jwt

from app.auth.claims import principal_from_claims
from app.auth.principal import Principal
from app.core.errors import AuthenticationError, ExpiredTokenError

ALGORITHMS: list[str] = ["HS256"]


class JwtTokenVerifier:
    """Verify HS256 tokens signed with a shared secret."""

    name = "jwt"

    def __init__(
        self, *, secret: str, issuer: str, audience: str, leeway_seconds: int
    ) -> None:
        """Configure the verifier; every argument is mandatory by design."""
        self._secret = secret
        self._issuer = issuer
        self._audience = audience
        self._leeway = leeway_seconds

    async def verify(self, token: str) -> Principal:
        """Decode and validate ``token``; translate library errors."""
        try:
            payload = jwt.decode(
                token,
                self._secret,
                algorithms=ALGORITHMS,
                audience=self._audience,
                issuer=self._issuer,
                leeway=self._leeway,
                options={"require": ["exp", "iat", "sub"]},
            )
        except jwt.ExpiredSignatureError as exc:
            raise ExpiredTokenError() from exc
        except jwt.InvalidTokenError as exc:
            # Library message may echo token internals: keep it out of the body.
            raise AuthenticationError("token could not be verified") from exc
        return principal_from_claims(payload, provider=self.name, token=token)


__all__ = ["ALGORITHMS", "JwtTokenVerifier"]
