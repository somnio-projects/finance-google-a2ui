"""Mint an HS256 token the ``jwt`` provider accepts — local stacks only.

Shared by ``scripts/mint_dev_token.py`` and the preview sign-in (spec 0027),
so there is one place that knows which claims the verifier requires (ADR-B
D-11: ``iss``, ``aud``, ``exp``, ``iat``, ``sub``). It signs with the shared
development secret; production verifies RS256 from an identity provider's
JWKS and cannot accept anything minted here.
"""

from collections.abc import Mapping
from datetime import UTC, datetime

import jwt


def build_token(
    *,
    subject: str,
    secret: str,
    issuer: str,
    audience: str,
    ttl_seconds: int,
    now: datetime | None = None,
    extra: Mapping[str, object] | None = None,
) -> str:
    """Return an HS256 token carrying the claims the jwt provider requires.

    Args:
        subject: The ``sub`` claim — who the token speaks for.
        secret: The shared HS256 secret (``AUTH_JWT_SECRET``).
        issuer: The ``iss`` claim, which must match ``AUTH_ISSUER``.
        audience: The ``aud`` claim, which must match ``AUTH_AUDIENCE``.
        ttl_seconds: How long the token stays valid.
        now: The issue instant; the wall clock when omitted.
        extra: Further claims — ``email``, and ``roles`` the verifier reads as
            scopes (``admin`` unlocks the admin routes).

    Returns:
        The encoded token, ready for an ``Authorization: Bearer`` header.
    """
    issued_at = int((now or datetime.now(tz=UTC)).timestamp())
    claims: dict[str, object] = {
        "sub": subject,
        "iss": issuer,
        "aud": audience,
        "iat": issued_at,
        "exp": issued_at + ttl_seconds,
    }
    claims.update(extra or {})
    return jwt.encode(claims, secret, algorithm="HS256")


__all__ = ["build_token"]
