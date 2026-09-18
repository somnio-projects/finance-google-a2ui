"""Fixed-window, per-client rate limiting (compensating control, ADR-G D-7).

In-memory by design for the single-instance review deployment. The limiter
is behind a tiny class so a Redis-backed implementation can replace it
without touching the middleware.
"""

from collections import defaultdict
from http import HTTPStatus

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.protocols import Clock
from app.helpers.tokens import extract_bearer, fingerprint

WINDOW_SECONDS = 60
EXEMPT_PATHS: frozenset[str] = frozenset({"/healthz", "/readyz"})


class FixedWindowLimiter:
    """Count hits per key inside the current minute."""

    def __init__(self, *, limit: int, clock: Clock) -> None:
        """Allow ``limit`` requests per key per ``WINDOW_SECONDS``."""
        self._limit = limit
        self._clock = clock
        self._window: int = -1
        self._hits: dict[str, int] = defaultdict(int)

    def allow(self, key: str) -> bool:
        """Register one hit for ``key`` and say whether it is within budget."""
        window = int(self._clock.now().timestamp()) // WINDOW_SECONDS
        if window != self._window:
            self._window, self._hits = window, defaultdict(int)
        self._hits[key] += 1
        return self._hits[key] <= self._limit


def client_key(request: Request) -> str:
    """Key by token fingerprint when present, else by client address."""
    token = extract_bearer(request.headers.get("authorization"))
    if token is not None:
        return f"token:{fingerprint(token)}"
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Answer 429 (problem+json) once a client exhausts its window."""

    def __init__(self, app: object, *, limiter: FixedWindowLimiter) -> None:
        """Create the middleware around an injected limiter."""
        super().__init__(app)  # pyright: ignore[reportArgumentType]
        self._limiter = limiter

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Check the budget for every non-exempt path."""
        if request.url.path in EXEMPT_PATHS or self._limiter.allow(client_key(request)):
            return await call_next(request)
        status = HTTPStatus.TOO_MANY_REQUESTS
        return JSONResponse(
            status_code=status.value,
            headers={"Retry-After": str(WINDOW_SECONDS)},
            content={
                "type": "https://errors.finance-a2ui/rate-limited",
                "title": status.phrase,
                "status": status.value,
                "detail": "too many requests; retry after the window resets",
            },
            media_type="application/problem+json",
        )


__all__ = [
    "EXEMPT_PATHS",
    "WINDOW_SECONDS",
    "FixedWindowLimiter",
    "RateLimitMiddleware",
    "client_key",
]
