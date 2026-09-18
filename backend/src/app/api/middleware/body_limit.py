"""Reject oversized request bodies before they are read (DoS hardening)."""

from http import HTTPStatus

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response


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
                return JSONResponse(
                    status_code=HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                    content={
                        "type": "https://errors.finance-a2ui/payload-too-large",
                        "title": HTTPStatus.REQUEST_ENTITY_TOO_LARGE.phrase,
                        "status": HTTPStatus.REQUEST_ENTITY_TOO_LARGE.value,
                        "detail": f"request body exceeds {self._max_bytes} bytes",
                    },
                    media_type="application/problem+json",
                )
        return await call_next(request)


__all__ = ["BodyLimitMiddleware"]
