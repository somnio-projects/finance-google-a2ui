"""Translate exceptions into RFC 9457 problem-details responses.

Three handlers cover everything: ``AppError`` (expected, typed), request
validation (422) and the catch-all (500). The catch-all never echoes the
exception text — it is reported to telemetry and answered generically.
"""

from http import HTTPStatus
from typing import Final

import structlog
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.core.errors import AppError
from app.core.logging import get_logger
from app.core.protocols import ErrorReporter
from app.schemas.problem import ProblemDetails

PROBLEM_TYPE_BASE: Final = "https://errors.finance-a2ui/"
log: structlog.stdlib.BoundLogger = get_logger(__name__)


def problem_response(
    request: Request, *, status: HTTPStatus, code: str, detail: str
) -> JSONResponse:
    """Build the JSON response for one problem."""
    body = ProblemDetails(
        type=f"{PROBLEM_TYPE_BASE}{code}",
        title=status.phrase,
        status=status.value,
        detail=detail,
        instance=str(request.url.path),
        request_id=getattr(request.state, "request_id", None),
    )
    return JSONResponse(
        status_code=status.value,
        content=body.model_dump(exclude_none=True),
        media_type="application/problem+json",
    )


def register_error_handlers(app: FastAPI, reporter: ErrorReporter) -> None:
    """Attach the three exception handlers to ``app``."""

    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError) -> JSONResponse:
        return problem_response(
            request, status=exc.status, code=exc.code, detail=exc.detail
        )

    @app.exception_handler(RequestValidationError)
    async def _validation(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return problem_response(
            request,
            status=HTTPStatus.UNPROCESSABLE_ENTITY,
            code="malformed-request",
            detail=f"{len(exc.errors())} request field(s) failed validation",
        )

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        reporter.capture_exception(exc)
        log.error("unhandled_exception", exc_info=exc)
        return problem_response(
            request,
            status=HTTPStatus.INTERNAL_SERVER_ERROR,
            code="internal",
            detail="an unexpected error occurred",
        )


__all__ = ["PROBLEM_TYPE_BASE", "problem_response", "register_error_handlers"]
