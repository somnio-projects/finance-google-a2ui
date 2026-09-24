"""Domain error hierarchy.

Services and repositories raise these; the API layer translates them into
RFC 9457 problem details (``app.api.errors``). Infrastructure exceptions are
translated into these at the adapter boundary and never leak upward.
"""

from http import HTTPStatus
from typing import Final

#: Base of every problem-details ``type`` URI. It lives here, beside the codes
#: it is concatenated with, so the API layer and the services that build a
#: nested problem (the batch render) share one spelling.
PROBLEM_TYPE_BASE: Final[str] = "https://errors.finance-a2ui/"


class AppError(Exception):
    """Base class for every error the application raises on purpose.

    Attributes:
        status: HTTP status the API layer should answer with.
        code: Stable, machine-readable identifier (``auth/expired-token``).
        detail: Human-readable, safe-to-expose explanation.
    """

    status: HTTPStatus = HTTPStatus.INTERNAL_SERVER_ERROR
    code: str = "internal"

    def __init__(self, detail: str | None = None) -> None:
        """Create the error with an optional safe detail message."""
        self.detail = detail or self.__class__.__doc__ or self.code
        super().__init__(self.detail)


class NotFoundError(AppError):
    """The requested resource does not exist."""

    status = HTTPStatus.NOT_FOUND
    code = "not-found"


class FeatureDisabledError(NotFoundError):
    """The endpoint is switched off by a feature flag (spec 0002)."""

    code = "feature-disabled"


class ValidationFailedError(AppError):
    """The request was well-formed but semantically invalid."""

    status = HTTPStatus.UNPROCESSABLE_ENTITY
    code = "validation-failed"


class AuthenticationError(AppError):
    """Credentials are missing or cannot be verified."""

    status = HTTPStatus.UNAUTHORIZED
    code = "auth/invalid-token"


class MissingTokenError(AuthenticationError):
    """No bearer token was supplied."""

    code = "auth/missing-token"


class ExpiredTokenError(AuthenticationError):
    """The bearer token has expired."""

    code = "auth/expired-token"


class AuthorizationError(AppError):
    """The caller is authenticated but may not perform this action."""

    status = HTTPStatus.FORBIDDEN
    code = "forbidden"


class NotProvisionedError(AuthorizationError):
    """This account isn't provisioned for the preview."""

    code = "not-provisioned"


class RateLimitedError(AppError):
    """Too many requests for this principal in the current window."""

    status = HTTPStatus.TOO_MANY_REQUESTS
    code = "rate-limited"


class DependencyUnavailableError(AppError):
    """A downstream dependency (database, identity provider) is unavailable."""

    status = HTTPStatus.SERVICE_UNAVAILABLE
    code = "dependency-unavailable"


class ConfigurationError(AppError):
    """The service is misconfigured; fail fast rather than serve requests."""

    code = "configuration"


__all__ = [
    "PROBLEM_TYPE_BASE",
    "AppError",
    "AuthenticationError",
    "AuthorizationError",
    "ConfigurationError",
    "DependencyUnavailableError",
    "ExpiredTokenError",
    "FeatureDisabledError",
    "MissingTokenError",
    "NotFoundError",
    "NotProvisionedError",
    "RateLimitedError",
    "ValidationFailedError",
]
