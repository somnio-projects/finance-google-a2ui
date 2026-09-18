import pytest

from app.auth.providers.jwt_provider import JwtTokenVerifier
from app.auth.providers.oidc_provider import OidcTokenVerifier
from app.auth.registry import FACTORIES, build_token_verifier
from app.core.errors import ConfigurationError
from app.helpers.clock import FixedClock
from tests.conftest import make_settings


def test_registry_builds_jwt_verifier(clock: FixedClock) -> None:
    verifier = build_token_verifier(make_settings(auth_provider="jwt"), clock)
    assert isinstance(verifier, JwtTokenVerifier)
    assert verifier.name == "jwt"


def test_registry_jwt_requires_secret(clock: FixedClock) -> None:
    settings = make_settings(auth_provider="jwt", auth_jwt_secret=None)
    with pytest.raises(ConfigurationError, match="AUTH_JWT_SECRET"):
        build_token_verifier(settings, clock)


def test_registry_builds_oidc_verifier(clock: FixedClock) -> None:
    settings = make_settings(
        auth_provider="oidc", auth_oidc_jwks_url="https://issuer.test/jwks"
    )
    verifier = build_token_verifier(settings, clock)
    assert isinstance(verifier, OidcTokenVerifier)
    assert verifier.name == "oidc"


def test_registry_oidc_requires_jwks_url(clock: FixedClock) -> None:
    settings = make_settings(auth_provider="oidc", auth_oidc_jwks_url=None)
    with pytest.raises(ConfigurationError, match="AUTH_OIDC_JWKS_URL"):
        build_token_verifier(settings, clock)


def test_registry_unknown_provider_raises(
    clock: FixedClock, monkeypatch: pytest.MonkeyPatch
) -> None:
    settings = make_settings()
    monkeypatch.delitem(FACTORIES, "jwt")
    with pytest.raises(ConfigurationError, match="unknown AUTH_PROVIDER"):
        build_token_verifier(settings, clock)
