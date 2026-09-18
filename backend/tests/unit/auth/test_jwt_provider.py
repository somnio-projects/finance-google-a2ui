import pytest

from app.auth.providers.jwt_provider import JwtTokenVerifier
from app.core.errors import AuthenticationError, ExpiredTokenError
from tests.conftest import (
    FROZEN_NOW,
    TEST_AUDIENCE,
    TEST_ISSUER,
    TEST_SECRET,
    make_token,
)


@pytest.fixture
def verifier() -> JwtTokenVerifier:
    return JwtTokenVerifier(
        secret=TEST_SECRET, issuer=TEST_ISSUER, audience=TEST_AUDIENCE, leeway_seconds=0
    )


async def test_jwt_verifier_accepts_valid_token(verifier: JwtTokenVerifier) -> None:
    token = make_token(subject="user-1", ttl_seconds=10**9, extra={"scope": "read"})
    principal = await verifier.verify(token)
    assert principal.subject == "user-1"
    assert principal.provider == "jwt"
    assert principal.scopes == frozenset({"read"})


async def test_jwt_verifier_rejects_expired_token(verifier: JwtTokenVerifier) -> None:
    token = make_token(now=FROZEN_NOW, ttl_seconds=1)
    with pytest.raises(ExpiredTokenError, match="expired"):
        await verifier.verify(token)


@pytest.mark.parametrize(
    "token",
    [
        make_token(
            secret="another-secret-that-is-long-enough-0123456789", ttl_seconds=10**9
        ),
        make_token(ttl_seconds=10**9, extra={"aud": "someone-else"}),
        make_token(ttl_seconds=10**9, extra={"iss": "https://evil.test"}),
        "not.a.jwt",
        "",
    ],
    ids=["wrong_secret", "wrong_audience", "wrong_issuer", "garbage", "empty"],
)
async def test_jwt_verifier_rejects_invalid_tokens_without_leaking_detail(
    verifier: JwtTokenVerifier, token: str
) -> None:
    with pytest.raises(AuthenticationError, match="could not be verified") as info:
        await verifier.verify(token)
    assert info.value.code == "auth/invalid-token"
