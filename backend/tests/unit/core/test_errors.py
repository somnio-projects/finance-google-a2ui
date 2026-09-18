from http import HTTPStatus

import pytest

from app.core import errors


@pytest.mark.parametrize(
    ("error_type", "status", "code"),
    [
        (errors.AppError, HTTPStatus.INTERNAL_SERVER_ERROR, "internal"),
        (errors.NotFoundError, HTTPStatus.NOT_FOUND, "not-found"),
        (
            errors.ValidationFailedError,
            HTTPStatus.UNPROCESSABLE_ENTITY,
            "validation-failed",
        ),
        (errors.AuthenticationError, HTTPStatus.UNAUTHORIZED, "auth/invalid-token"),
        (errors.MissingTokenError, HTTPStatus.UNAUTHORIZED, "auth/missing-token"),
        (errors.ExpiredTokenError, HTTPStatus.UNAUTHORIZED, "auth/expired-token"),
        (errors.AuthorizationError, HTTPStatus.FORBIDDEN, "forbidden"),
        (errors.RateLimitedError, HTTPStatus.TOO_MANY_REQUESTS, "rate-limited"),
        (
            errors.DependencyUnavailableError,
            HTTPStatus.SERVICE_UNAVAILABLE,
            "dependency-unavailable",
        ),
        (errors.ConfigurationError, HTTPStatus.INTERNAL_SERVER_ERROR, "configuration"),
    ],
    ids=lambda value: getattr(value, "__name__", str(value)),
)
def test_error_hierarchy_carries_status_and_code(
    error_type: type[errors.AppError], status: HTTPStatus, code: str
) -> None:
    error = error_type()
    assert isinstance(error, errors.AppError)
    assert error.status is status
    assert error.code == code
    assert error.detail  # docstring used as the default detail


def test_app_error_custom_detail_wins_over_docstring() -> None:
    error = errors.NotFoundError("thing 42 not found")
    assert error.detail == "thing 42 not found"
    assert str(error) == "thing 42 not found"


def test_subclass_relationships_allow_catching_by_category() -> None:
    assert issubclass(errors.MissingTokenError, errors.AuthenticationError)
    assert issubclass(errors.ExpiredTokenError, errors.AuthenticationError)
