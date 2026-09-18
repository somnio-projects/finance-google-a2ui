"""Authenticate a request: header → verified ``Principal``.

Sits between the controller dependency and the ``TokenVerifier`` so the
header parsing, error mapping and telemetry live in one testable place.
"""

from app.auth.principal import Principal
from app.core.errors import AuthenticationError, MissingTokenError
from app.core.protocols import ErrorReporter, TokenVerifier
from app.helpers.tokens import extract_bearer


class AuthService:
    """Turn an ``Authorization`` header into a ``Principal``."""

    def __init__(self, *, verifier: TokenVerifier, reporter: ErrorReporter) -> None:
        """Inject the configured verifier and the telemetry sink."""
        self._verifier = verifier
        self._reporter = reporter

    async def authenticate(self, authorization: str | None) -> Principal:
        """Verify the bearer token carried by ``authorization``.

        Raises:
            MissingTokenError: No bearer token present.
            AuthenticationError: Token present but rejected by the verifier.
        """
        token = extract_bearer(authorization)
        if token is None:
            self._reporter.increment("auth.rejected", tags={"code": "missing-token"})
            raise MissingTokenError()
        try:
            principal = await self._verifier.verify(token)
        except AuthenticationError as exc:
            self._reporter.increment("auth.rejected", tags={"code": exc.code})
            raise
        self._reporter.increment("auth.accepted", tags={"provider": principal.provider})
        return principal


__all__ = ["AuthService"]
