"""Install the HTTP hardening stack, outermost first.

Lifted out of the composition root because it is a different question: the
root decides *what the object graph is*, this decides *what every request
passes through*. `bootstrap.py` was also over the 150-line budget, and this is
the part that grows whenever a header or a limit is added.

**Order is the contract.** Request id is outermost so every later layer and
every log line has one; the rate limiter is innermost so a rejected request
has still been identified and host-checked. Reordering these is a security
change, not a tidy-up (`.claude/rules/backend/security.md`).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from app.api.container import Container
from app.api.middleware.body_limit import BodyLimitMiddleware
from app.api.middleware.rate_limit import FixedWindowLimiter, RateLimitMiddleware
from app.api.middleware.request_id import RequestIdMiddleware
from app.api.middleware.security_headers import SecurityHeadersMiddleware


def install_middleware(app: FastAPI, container: Container) -> None:
    """Order matters: outermost first (request id) to innermost (rate limit)."""
    settings = container.settings
    app.add_middleware(
        RateLimitMiddleware,
        limiter=FixedWindowLimiter(
            limit=settings.rate_limit_per_minute, clock=container.clock
        ),
    )
    app.add_middleware(BodyLimitMiddleware, max_bytes=settings.max_request_body_bytes)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        # `X-A2A-Extensions` is the header the A2UI client declares its
        # extension in on every turn; without it here the browser's preflight
        # to `/` was a 400 and the Assistant could not reach the agent at all
        # (spec 0029 §2). curl never sends a preflight, which is how it hid.
        allow_headers=[
            "Authorization",
            "Content-Type",
            "X-Request-ID",
            "X-A2A-Extensions",
        ],
    )
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_hosts)
    app.add_middleware(SecurityHeadersMiddleware, enable_hsts=settings.is_production)
    app.add_middleware(RequestIdMiddleware)


__all__ = ["install_middleware"]
