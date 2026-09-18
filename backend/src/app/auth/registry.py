"""Choose the ``TokenVerifier`` implementation from settings.

This is the extension point for new authentication schemes: register a
factory under a new ``AuthProviderName`` and nothing else changes.
"""

from collections.abc import Callable

from app.auth.providers.jwks import JwksKeyResolver
from app.auth.providers.jwt_provider import JwtTokenVerifier
from app.auth.providers.oidc_provider import OidcTokenVerifier
from app.core.config import Settings
from app.core.errors import ConfigurationError
from app.core.protocols import Clock, TokenVerifier

VerifierFactory = Callable[[Settings, Clock], TokenVerifier]


def _build_jwt(settings: Settings, _clock: Clock) -> TokenVerifier:
    if settings.auth_jwt_secret is None:
        raise ConfigurationError("AUTH_JWT_SECRET is required when AUTH_PROVIDER=jwt")
    return JwtTokenVerifier(
        secret=settings.auth_jwt_secret.get_secret_value(),
        issuer=settings.auth_issuer,
        audience=settings.auth_audience,
        leeway_seconds=settings.auth_leeway_seconds,
    )


def _build_oidc(settings: Settings, clock: Clock) -> TokenVerifier:
    if settings.auth_oidc_jwks_url is None:
        raise ConfigurationError(
            "AUTH_OIDC_JWKS_URL is required when AUTH_PROVIDER=oidc"
        )
    resolver = JwksKeyResolver(jwks_url=settings.auth_oidc_jwks_url, clock=clock)
    return OidcTokenVerifier(
        resolver=resolver,
        issuer=settings.auth_issuer,
        audience=settings.auth_audience,
        leeway_seconds=settings.auth_leeway_seconds,
    )


FACTORIES: dict[str, VerifierFactory] = {
    "jwt": _build_jwt,
    "oidc": _build_oidc,
}


def build_token_verifier(settings: Settings, clock: Clock) -> TokenVerifier:
    """Return the verifier selected by ``settings.auth_provider``.

    Raises:
        ConfigurationError: Unknown provider or missing provider-specific setting.
    """
    try:
        factory = FACTORIES[settings.auth_provider]
    except KeyError as exc:
        raise ConfigurationError(
            f"unknown AUTH_PROVIDER {settings.auth_provider!r}"
        ) from exc
    return factory(settings, clock)


__all__ = ["FACTORIES", "VerifierFactory", "build_token_verifier"]
