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

from app.auth.dev_tokens import build_token

DEFAULT_TTL_SECONDS = 3600


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
