"""``build_token`` — one place knows which claims the jwt provider needs."""

import jwt

from app.auth.dev_tokens import build_token
from tests.conftest import FROZEN_NOW, TEST_AUDIENCE, TEST_ISSUER, TEST_SECRET


def _decode(token: str) -> dict[str, object]:
    return jwt.decode(
        token,
        TEST_SECRET,
        algorithms=["HS256"],
        audience=TEST_AUDIENCE,
        issuer=TEST_ISSUER,
        options={"verify_exp": False},
    )


def test_the_required_claims_and_only_those_by_default() -> None:
    claims = _decode(
        build_token(
            subject="alice",
            secret=TEST_SECRET,
            issuer=TEST_ISSUER,
            audience=TEST_AUDIENCE,
            ttl_seconds=60,
            now=FROZEN_NOW,
        )
    )
    assert set(claims) == {"sub", "iss", "aud", "iat", "exp"}
    assert claims["iat"] == int(FROZEN_NOW.timestamp())
    assert claims["exp"] == int(FROZEN_NOW.timestamp()) + 60


def test_email_and_roles_travel_when_given_and_now_defaults_to_the_clock() -> None:
    claims = _decode(
        build_token(
            subject="a@b.test",
            secret=TEST_SECRET,
            issuer=TEST_ISSUER,
            audience=TEST_AUDIENCE,
            ttl_seconds=60,
            extra={"email": "a@b.test", "roles": ["admin"]},
        )
    )
    assert (claims["email"], claims["roles"]) == ("a@b.test", ["admin"])
    assert isinstance(claims["iat"], int)
