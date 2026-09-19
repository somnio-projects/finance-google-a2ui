"""Pure helpers for handling bearer tokens safely."""

import hashlib

BEARER_PREFIX = "bearer "


def extract_bearer(authorization: str | None) -> str | None:
    """Return the token from an ``Authorization: Bearer <token>`` header.

    Returns ``None`` when the header is missing, uses another scheme or the
    token part is empty. The comparison is case-insensitive for the scheme
    only, as RFC 6750 requires.
    """
    if authorization is None:
        return None
    if not authorization.lower().startswith(BEARER_PREFIX):
        return None
    token = authorization[len(BEARER_PREFIX) :].strip()
    return token or None


def fingerprint(token: str) -> str:
    """Return a short, non-reversible identifier for a token.

    Used in logs and audit events so a token can be correlated without ever
    being stored (SOC 2 CC6.7 — no credentials at rest in logs).
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]


__all__ = ["BEARER_PREFIX", "extract_bearer", "fingerprint"]
