"""Mint a local development bearer token (`make token SUBJECT=alice`).

Every route except the health ones is authenticated, so without this a fresh
clone cannot call anything and the README's clone-and-run promise is false
(spec `repo/0001` AC-2).

It is deliberately **local only**. It signs with `AUTH_JWT_SECRET` from the
environment, which is the HS256 development secret; it cannot mint anything a
production service would accept, because production runs `AUTH_PROVIDER=oidc`
and verifies RS256 signatures from an identity provider's JWKS endpoint.
"""

import argparse
import os
import sys
import time

import jwt

DEFAULT_TTL_SECONDS = 3600


def build_token(
    *, subject: str, secret: str, issuer: str, audience: str, ttl_seconds: int
) -> str:
    """Return an HS256 token carrying the claims the jwt provider requires.

    Args:
        subject: The `sub` claim — who the token speaks for.
        secret: The shared HS256 secret (`AUTH_JWT_SECRET`).
        issuer: The `iss` claim, which must match `AUTH_ISSUER`.
        audience: The `aud` claim, which must match `AUTH_AUDIENCE`.
        ttl_seconds: How long the token stays valid.

    Returns:
        The encoded token, ready for an `Authorization: Bearer` header.
    """
    issued_at = int(time.time())
    return jwt.encode(
        {
            "sub": subject,
            "iss": issuer,
            "aud": audience,
            "iat": issued_at,
            "exp": issued_at + ttl_seconds,
        },
        secret,
        algorithm="HS256",
    )


def main() -> int:
    """Parse the arguments, read the environment, print one token."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--subject", default="alice", help="the `sub` claim")
    parser.add_argument("--ttl", type=int, default=DEFAULT_TTL_SECONDS)
    args = parser.parse_args()

    secret = os.environ.get("AUTH_JWT_SECRET", "")
    if not secret:
        print(
            "AUTH_JWT_SECRET is not set. Copy backend/env.example to "
            "backend/.env and export it, or pass it inline.",
            file=sys.stderr,
        )
        return 1

    print(
        build_token(
            subject=args.subject,
            secret=secret,
            issuer=os.environ.get("AUTH_ISSUER", "https://issuer.example"),
            audience=os.environ.get("AUTH_AUDIENCE", "finance-a2ui"),
            ttl_seconds=args.ttl,
        )
    )
    return 0


if __name__ == "__main__":  # pragma: no cover - a command-line entry point
    raise SystemExit(main())
