"""Fixed-window rate limiting (compensating control, ADR-G D-7).

Every request is counted against the **client address**; requests that carry
a bearer token are additionally counted against the token fingerprint. The
token is unverified at this point, so it can never widen the budget — a
caller rotating garbage tokens still exhausts the per-IP window.

In-memory by design for the single-instance review deployment. The limiter
is a small class so a Redis-backed implementation can replace it without
touching the middleware.
"""

from collections import defaultdict
from http import HTTPStatus

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from app.api.errors import problem_response
from app.core.protocols import Clock
from app.helpers.tokens import extract_bearer, fingerprint

WINDOW_SECONDS = 60
EXEMPT_PATHS: frozenset[str] = frozenset({"/health", "/readyz"})


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


def client_keys(request: Request) -> list[str]:
    """Return the keys a request is counted against: always IP, plus token."""
    host = request.client.host if request.client else "unknown"
    keys = [f"ip:{host}"]
    token = extract_bearer(request.headers.get("authorization"))
    if token is not None:
        keys.append(f"token:{fingerprint(token)}")
    return keys


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Answer 429 (problem+json) once a client exhausts its window."""

    def __init__(self, app: object, *, limiter: FixedWindowLimiter) -> None:
        """Create the middleware around an injected limiter."""
        super().__init__(app)  # pyright: ignore[reportArgumentType]
        self._limiter = limiter

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Check every budget for non-exempt paths; any exhausted key blocks."""
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)
        verdicts = [self._limiter.allow(key) for key in client_keys(request)]
        if all(verdicts):
            return await call_next(request)
        response = problem_response(
            request,
            status=HTTPStatus.TOO_MANY_REQUESTS,
            code="rate-limited",
            detail="too many requests; retry after the window resets",
        )
        response.headers["Retry-After"] = str(WINDOW_SECONDS)
        return response


__all__ = [
    "EXEMPT_PATHS",
    "WINDOW_SECONDS",
    "FixedWindowLimiter",
    "RateLimitMiddleware",
    "client_keys",
]
