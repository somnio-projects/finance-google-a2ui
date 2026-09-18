"""Defensive HTTP response headers (OWASP Secure Headers, ISO 27001 A.8.26).

HSTS is only sent when running in production behind TLS; sending it over
plain HTTP in development would poison browsers against ``localhost``.
"""

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

BASE_HEADERS: dict[str, str] = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-store",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
}
HSTS_HEADER = ("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
# Interactive API docs need inline scripts/styles from the FastAPI CDN bundle.
DOCS_PATHS: frozenset[str] = frozenset({"/docs", "/redoc"})
DOCS_CSP = (
    "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
    "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
    "img-src 'self' data: https://fastapi.tiangolo.com; frame-ancestors 'none'"
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add the hardening headers to every response."""

    def __init__(self, app: object, *, enable_hsts: bool) -> None:
        """Create the middleware; ``enable_hsts`` is true only in production."""
        super().__init__(app)  # pyright: ignore[reportArgumentType]
        self._enable_hsts = enable_hsts

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Set headers after the downstream app produced the response."""
        response = await call_next(request)
        for name, value in BASE_HEADERS.items():
            response.headers.setdefault(name, value)
        if request.url.path in DOCS_PATHS:
            response.headers["Content-Security-Policy"] = DOCS_CSP
        if self._enable_hsts:
            response.headers.setdefault(*HSTS_HEADER)
        return response


__all__ = ["BASE_HEADERS", "DOCS_CSP", "HSTS_HEADER", "SecurityHeadersMiddleware"]
