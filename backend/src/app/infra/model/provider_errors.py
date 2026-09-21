"""What a provider failure means, and what it said (GGU-90 AC-4).

Two questions about one failed attempt, kept together because they are asked
together and answered from the same exception: **is another attempt worth
making**, and **what did the provider actually say**.

``GeminiModelClient`` masks every provider failure as
``DependencyUnavailableError`` with a fixed message, and that is right at the
API boundary: a caller learns that a dependency is down, never how our request
to it was shaped (spec 0006 AC-3). But the mask was total — the text went
nowhere at all — so two 400s that broke **every** agent turn (GGU-90, GGU-88)
looked from the outside like an unavailable provider, and each cost an hour to
find by replaying the call by hand.

Masking outward and recording inward are different decisions. This module is
the inward half: one ``warning`` per failed attempt, in the server's own logs,
naming the status and quoting the provider's diagnostic.

**Why this is not a leak.** The log line is server-side; nothing here reaches
the client, and ``gemini_client`` still raises the same fixed message. The API
key cannot appear: it travels in a request header, and this reads only the
*response* body. What a ``generateContent`` rejection contains is a complaint
about our own request's shape — a field path, a role name, a missing
signature — so the text is ours, not the user's. It is still truncated at
``MAX_DETAIL_CHARS``: a bound is cheaper than trusting a third party to stay
terse, and a diagnostic that needs more than that is one to reproduce by hand
anyway.
"""

from typing import Final

import httpx
import structlog

from app.core.logging import get_logger

log: structlog.stdlib.BoundLogger = get_logger(__name__)

#: How much of a provider's complaint is worth keeping. Long enough for the
#: two that have actually bitten us, short enough to bound a log line.
MAX_DETAIL_CHARS: Final[int] = 800

#: Statuses where another attempt could plausibly land differently.
RETRYABLE_STATUS: Final[frozenset[int]] = frozenset({408, 429, 500, 502, 503, 504})


def is_retryable(exc: BaseException) -> bool:
    """Return True when another attempt could plausibly succeed.

    Args:
        exc: The failure from one attempt.

    Returns:
        True for a transport failure or a retryable status; False for a
        rejected request (a bad key retried three times is still a bad key)
        and for a body that cannot be parsed.
    """
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code in RETRYABLE_STATUS
    return isinstance(exc, httpx.TransportError)


def log_provider_failure(exc: BaseException) -> None:
    """Record one failed attempt against the model provider.

    Args:
        exc: The failure from a single attempt, before any retry decision.

    A status error is logged with the provider's own body, which is the part
    that says *why*; anything else (timeout, connection refused, a body that
    is not JSON) has no provider text to quote, so only the exception type is
    recorded — its message could carry the URL we called.
    """
    if isinstance(exc, httpx.HTTPStatusError):
        log.warning(
            "model_provider_rejected",
            status=exc.response.status_code,
            detail=exc.response.text[:MAX_DETAIL_CHARS],
        )
        return
    log.warning("model_provider_unreachable", error=type(exc).__name__)


__all__ = [
    "MAX_DETAIL_CHARS",
    "RETRYABLE_STATUS",
    "is_retryable",
    "log_provider_failure",
]
