from datetime import timedelta

import jwt
import pytest

from app.auth.providers.oidc_provider import OidcTokenVerifier
from app.core.errors import AuthenticationError, ExpiredTokenError
from tests.conftest import FROZEN_NOW, TEST_AUDIENCE, TEST_ISSUER
from tests.unit.auth.rsa_fixture import JWKS, rs256_token


class StaticResolver:
    """``KeyResolver`` backed by the fixture JWKS, no network."""

    async def ensure_fresh(self) -> None:
        return None

    def key_for(self, token: str) -> jwt.PyJWK:
        header = jwt.get_unverified_header(token)
        return jwt.PyJWKSet.from_dict(JWKS)[header["kid"]]


@pytest.fixture
def verifier() -> OidcTokenVerifier:
    return OidcTokenVerifier(
        resolver=StaticResolver(),
        issuer=TEST_ISSUER,
        audience=TEST_AUDIENCE,
        leeway_seconds=0,
    )


async def test_oidc_verifier_accepts_rs256_token(verifier: OidcTokenVerifier) -> None:
    token = rs256_token(subject="firebase-uid", now=FROZEN_NOW, ttl_seconds=10**9)
    principal = await verifier.verify(token)
    assert principal.subject == "firebase-uid"
    assert principal.provider == "oidc"


async def test_oidc_verifier_rejects_expired_token(verifier: OidcTokenVerifier) -> None:
    old = FROZEN_NOW - timedelta(days=365)
    with pytest.raises(ExpiredTokenError, match="expired"):
        await verifier.verify(rs256_token(subject="s", now=old, ttl_seconds=1))


@pytest.mark.parametrize(
    "token",
    [
        rs256_token(subject="s", now=FROZEN_NOW, ttl_seconds=10**9, kid="unknown"),
        rs256_token(
            subject="s", now=FROZEN_NOW, ttl_seconds=10**9, issuer="https://evil.test"
        ),
        "garbage",
    ],
    ids=["unknown_kid", "wrong_issuer", "garbage"],
)
async def test_oidc_verifier_rejects_invalid_tokens(
    verifier: OidcTokenVerifier, token: str
) -> None:
    with pytest.raises(AuthenticationError, match="could not be verified"):
        await verifier.verify(token)
