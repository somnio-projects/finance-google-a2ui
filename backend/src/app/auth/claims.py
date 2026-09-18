"""Translate a decoded token payload into a ``Principal``.

Shared by every verifier so claim handling (scope normalisation, subject
validation) has exactly one implementation.
"""

from collections.abc import Mapping
from typing import Any

from app.auth.principal import Principal
from app.core.errors import AuthenticationError
from app.helpers.tokens import fingerprint


def _scopes_from(payload: Mapping[str, Any]) -> frozenset[str]:
    """Collect scopes from the common ``scope``/``scp``/``roles`` claims."""
    raw: list[str] = []
    for key in ("scope", "scp", "roles"):
        value = payload.get(key)
        if isinstance(value, str):
            raw.extend(value.split())
        elif isinstance(value, list):
            raw.extend(str(item) for item in value)  # pyright: ignore[reportUnknownVariableType]
    return frozenset(scope.lower() for scope in raw if scope)


def principal_from_claims(
    payload: Mapping[str, Any], *, provider: str, token: str
) -> Principal:
    """Build a ``Principal`` from verified claims.

    Raises:
        AuthenticationError: When the mandatory ``sub`` claim is missing.
    """
    subject = payload.get("sub")
    if not isinstance(subject, str) or not subject:
        raise AuthenticationError("token has no usable subject claim")
    email = payload.get("email")
    return Principal(
        subject=subject,
        provider=provider,
        email=email if isinstance(email, str) else None,
        scopes=_scopes_from(payload),
        token_fingerprint=fingerprint(token),
    )


__all__ = ["principal_from_claims"]
