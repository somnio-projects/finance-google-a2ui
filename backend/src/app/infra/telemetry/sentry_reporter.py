"""Sentry-backed ``ErrorReporter``.

Initialised once from the composition root. ``send_default_pii`` stays off
and request bodies are never attached (SOC 2 P4 / ISO A.8.11 — no personal
data in third-party telemetry).
"""

from collections.abc import Mapping

import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration


class SentryErrorReporter:
    """Forward exceptions and counters to Sentry."""

    def __init__(
        self,
        *,
        dsn: str,
        environment: str,
        release: str,
        traces_sample_rate: float,
    ) -> None:
        """Initialise the Sentry SDK for this process."""
        sentry_sdk.init(
            dsn=dsn,
            environment=environment,
            release=release,
            traces_sample_rate=traces_sample_rate,
            send_default_pii=False,
            max_request_body_size="never",
            integrations=[StarletteIntegration(), FastApiIntegration()],
        )

    def capture_exception(self, exc: BaseException) -> None:
        """Send the exception to Sentry."""
        sentry_sdk.capture_exception(exc)

    def increment(self, metric: str, *, tags: Mapping[str, str] | None = None) -> None:
        """Record a counter as a Sentry breadcrumb-compatible metric event.

        Sentry's metrics API changes between SDK majors; a breadcrumb keeps the
        signal attached to the next error without depending on it.
        """
        sentry_sdk.add_breadcrumb(
            category="metric", message=metric, data=dict(tags or {}), level="info"
        )


__all__ = ["SentryErrorReporter"]
