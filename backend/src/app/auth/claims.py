"""Translate a decoded token payload into a ``Principal``.

Shared by every verifier so claim handling (scope normalisation, subject
validation) has exactly one implementation. The payload PyJWT returns is an
untyped dict; ``JwtClaims`` is the boundary model that gives it a shape.
"""

from collections.abc import Mapping

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from app.core.errors import AuthenticationError
from app.core.principal import Principal
from app.helpers.tokens import fingerprint


class JwtClaims(BaseModel):
    """The claims this service reads from a verified token.

    Unknown claims are kept (``extra="allow"``) but never interpreted. The
    scope-bearing claims are normalised to ``list[str]`` before validation so
    a provider sending a space-separated string or a list of roles both work.
    """

    model_config = ConfigDict(frozen=True, extra="allow")

    sub: str = Field(min_length=1)
    email: str | None = None
    scope: list[str] = Field(default_factory=list)
    scp: list[str] = Field(default_factory=list)
    roles: list[str] = Field(default_factory=list)

    @field_validator("email", mode="before")
    @classmethod
    def _string_or_none(cls, value: object) -> str | None:
        """Drop non-string emails instead of rejecting the token."""
        return value if isinstance(value, str) else None

    @field_validator("scope", "scp", "roles", mode="before")
    @classmethod
    def _as_scope_list(cls, value: object) -> list[str]:
        """Accept ``"read write"`` or ``["read", "write"]``; ignore anything else."""
        if isinstance(value, str):
            return value.split()
        if isinstance(value, list):
            return [str(item) for item in value]  # pyright: ignore[reportUnknownVariableType]
        return []

    @property
    def scopes(self) -> frozenset[str]:
        """Lower-cased union of every scope-bearing claim."""
        raw = [*self.scope, *self.scp, *self.roles]
        return frozenset(scope.lower() for scope in raw if scope)


def principal_from_claims(
    payload: Mapping[str, object], *, provider: str, token: str
) -> Principal:
    """Build a ``Principal`` from verified claims.

    Raises:
        AuthenticationError: When the mandatory ``sub`` claim is missing.
    """
    try:
        claims = JwtClaims.model_validate(payload)
    except ValidationError as exc:
        # Only ``sub`` can fail: every other field is coerced to a safe value.
        raise AuthenticationError("token has no usable subject claim") from exc
    return Principal(
        subject=claims.sub,
        provider=provider,
        email=claims.email,
        scopes=claims.scopes,
        token_fingerprint=fingerprint(token),
    )


__all__ = ["JwtClaims", "principal_from_claims"]
