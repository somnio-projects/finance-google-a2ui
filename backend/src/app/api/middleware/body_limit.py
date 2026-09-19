"""Reject oversized request bodies before they are read (DoS hardening)."""

from http import HTTPStatus

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from app.api.errors import problem_response


class BodyLimitMiddleware(BaseHTTPMiddleware):
    """Answer 413 when ``Content-Length`` exceeds the configured maximum."""

    def __init__(self, app: object, *, max_bytes: int) -> None:
        """Create the middleware with the byte ceiling from settings."""
        super().__init__(app)  # pyright: ignore[reportArgumentType]
        self._max_bytes = max_bytes

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Short-circuit when the declared length is too large."""
        declared = request.headers.get("content-length")
        if declared is not None and declared.isdigit():
            if int(declared) > self._max_bytes:
                return problem_response(
                    request,
                    status=HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                    code="payload-too-large",
                    detail=f"request body exceeds {self._max_bytes} bytes",
                )
        return await call_next(request)


__all__ = ["BodyLimitMiddleware"]
