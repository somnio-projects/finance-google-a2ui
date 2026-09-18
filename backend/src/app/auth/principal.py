"""The authenticated caller as seen by the rest of the application."""

from pydantic import BaseModel, ConfigDict, Field


class Principal(BaseModel):
    """Identity extracted from a verified token.

    Attributes:
        subject: Stable unique identifier from the identity provider (``sub``).
        provider: Which verifier produced this principal (``jwt``, ``oidc``).
        email: Verified e-mail when the provider supplies one.
        scopes: Granted scopes / roles, already normalised to lowercase.
        token_fingerprint: Non-reversible correlation id for the token used.
    """

    model_config = ConfigDict(frozen=True)

    subject: str = Field(min_length=1, max_length=255)
    provider: str = Field(min_length=1, max_length=32)
    email: str | None = Field(default=None, max_length=320)
    scopes: frozenset[str] = Field(default_factory=frozenset)
    token_fingerprint: str = Field(min_length=8, max_length=64)

    def has_scope(self, scope: str) -> bool:
        """Return True when the principal was granted ``scope``."""
        return scope.lower() in self.scopes


__all__ = ["Principal"]
