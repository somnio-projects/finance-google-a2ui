"""Structural interfaces (``Protocol``) that decouple layers from adapters.

Inner layers depend on these shapes; ``app.infra`` and ``app.auth`` provide
the concrete implementations, wired together in ``app.bootstrap``.
"""

from collections.abc import Mapping
from datetime import datetime
from typing import Protocol

from app.auth.principal import Principal


class Clock(Protocol):
    """Source of the current time — injected so tests are deterministic."""

    def now(self) -> datetime:
        """Return the current time as an aware UTC datetime."""
        ...


class TokenVerifier(Protocol):
    """Verify a bearer token and return the authenticated principal.

    Implementations MUST raise ``app.core.errors.AuthenticationError`` (or a
    subclass) for every failure mode and never return a partially-verified
    principal.
    """

    @property
    def name(self) -> str:
        """Provider identifier recorded in audit events (``jwt``, ``oidc``)."""
        ...

    async def verify(self, token: str) -> Principal:
        """Validate signature, issuer, audience and expiry of ``token``."""
        ...


class ErrorReporter(Protocol):
    """Error/metrics engine facade (Sentry in production, a fake in tests)."""

    def capture_exception(self, exc: BaseException) -> None:
        """Report an unexpected exception."""
        ...

    def increment(self, metric: str, *, tags: Mapping[str, str] | None = None) -> None:
        """Increment a counter metric."""
        ...


class ReadinessProbe(Protocol):
    """Answer whether a dependency can currently serve traffic."""

    @property
    def name(self) -> str:
        """Dependency identifier shown in ``/readyz``."""
        ...

    async def check(self) -> bool:
        """Return True when the dependency is reachable."""
        ...


__all__ = ["Clock", "ErrorReporter", "ReadinessProbe", "TokenVerifier"]
