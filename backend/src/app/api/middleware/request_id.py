"""Correlation id per request, propagated to logs and responses."""

import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

HEADER = "X-Request-ID"
MAX_LENGTH = 64


def _incoming_or_new(value: str | None) -> str:
    """Reuse a sane client-provided id, otherwise mint a UUID4."""
    if value and len(value) <= MAX_LENGTH and value.isprintable():
        return value
    return str(uuid.uuid4())


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Set ``request.state.request_id`` and echo it back as a header."""

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Bind the id into structlog's context for the request lifetime."""
        request_id = _incoming_or_new(request.headers.get(HEADER))
        request.state.request_id = request_id
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)
        try:
            response = await call_next(request)
        finally:
            structlog.contextvars.clear_contextvars()
        response.headers[HEADER] = request_id
        return response


__all__ = ["HEADER", "MAX_LENGTH", "RequestIdMiddleware"]
