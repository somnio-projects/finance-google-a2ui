"""OIDC / SSO verifier: RS256 tokens validated against the provider's JWKS.

Works for any OpenID Connect issuer — Firebase Auth, Google Identity,
Auth0, Okta... The issuer and audience come from settings; keys come from
the JWKS endpoint through a ``KeyResolver``.
"""

import jwt

from app.auth.claims import principal_from_claims
from app.auth.providers.jwks import KeyResolver
from app.core.errors import AuthenticationError, ExpiredTokenError
from app.core.principal import Principal

ALGORITHMS: list[str] = ["RS256", "ES256"]


class OidcTokenVerifier:
    """Verify asymmetric tokens issued by an OIDC provider."""

    name = "oidc"

    def __init__(
        self,
        *,
        resolver: KeyResolver,
        issuer: str,
        audience: str,
        leeway_seconds: int,
    ) -> None:
        """Configure the verifier with an injected key resolver."""
        self._resolver = resolver
        self._issuer = issuer
        self._audience = audience
        self._leeway = leeway_seconds

    async def verify(self, token: str) -> Principal:
        """Resolve the signing key, then validate the token's claims."""
        try:
            await self._resolver.ensure_fresh()
            key = self._resolver.key_for(token)
            payload = jwt.decode(
                token,
                key,
                algorithms=ALGORITHMS,
                audience=self._audience,
                issuer=self._issuer,
                leeway=self._leeway,
                options={"require": ["exp", "iat", "sub"]},
            )
        except jwt.ExpiredSignatureError as exc:
            raise ExpiredTokenError() from exc
        except (jwt.PyJWTError, KeyError) as exc:
            # KeyError: unknown ``kid``. Never echo library text to the caller.
            raise AuthenticationError("token could not be verified") from exc
        return principal_from_claims(payload, provider=self.name, token=token)


__all__ = ["ALGORITHMS", "OidcTokenVerifier"]
