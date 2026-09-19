"""The authenticated caller as seen by the rest of the application.

Lives in ``core`` so the ``TokenVerifier`` protocol and every layer can
depend on it without importing the ``auth`` adapters.
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field

# RFC 8176 ``amr`` values that count as a second factor.
MFA_METHODS: Final = frozenset({"mfa", "otp", "hwk", "swk", "sms", "fido"})


class Principal(BaseModel):
    """Identity extracted from a verified token.

    Attributes:
        subject: Stable unique identifier from the identity provider (``sub``).
        provider: Which verifier produced this principal (``jwt``, ``oidc``).
        email: E-mail claim when the provider supplies one (not re-verified here).
        scopes: Granted scopes / roles, already normalised to lowercase.
        token_fingerprint: Non-reversible correlation id for the token used.
        auth_methods: ``amr`` claim values (RFC 8176), lowercase; empty when absent.
    """

    model_config = ConfigDict(frozen=True)

    subject: str = Field(min_length=1, max_length=255)
    provider: str = Field(min_length=1, max_length=32)
    email: str | None = Field(default=None, max_length=320)
    scopes: frozenset[str] = Field(default_factory=frozenset)
    token_fingerprint: str = Field(min_length=8, max_length=64)
    auth_methods: frozenset[str] = Field(default_factory=frozenset)

    def has_scope(self, scope: str) -> bool:
        """Return True when the principal was granted ``scope``."""
        return scope.lower() in self.scopes

    @property
    def is_mfa(self) -> bool:
        """Return True when the token was obtained with a second factor."""
        return not self.auth_methods.isdisjoint(MFA_METHODS)


__all__ = ["MFA_METHODS", "Principal"]
